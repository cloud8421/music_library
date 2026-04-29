defmodule MusicLibrary.Chats.Session do
  @moduledoc """
  A `:gen_statem` process managing a single chat session with the OpenAI Responses
  streaming API.

  ## State diagram

  ```
                   ┌──────────────────────────────────────────────────┐
                   │                                                  │
                   │   send_message (call)          ┌─────────────┐   │
                   │  ┌─────────────────────────────│  streaming  │   │
                   │  │                             └─────────────┘   │
                   │  │                                │    │         │
                   ▼  │                     stream ok  │    │ error   │
               ┌──────┴──┐      ┌──────────────────────┘    │         │
               │  idle   │      │                           │         │
               └─────────┘      │             retryable &   │         │
                    ▲           │            retries < max  │         │
                    │           │                ┌──────────┘         │
                    │           │                ▼                    │
                    │           │          ┌──────────┐               │
                    │           │          │  failed  │───────────────┘
                    │           │          └──────────┘  permanent or
                    │           │               │         exhausted
                    │           │  state_timeout│
                    │           │    (:retry)   │
                    │           │◄──────────────┘
                    │           │
                    ◀───────────┘
               permanent or
               success
  ```

  | State       | get_history     | send_message        | Internal events                 |
  |-------------|-----------------|---------------------|---------------------------------|
  | `:idle`     | returns chat    | persists & streams  | —                               |
  | `:streaming`| returns chat    | `{:error, :busy}`   | `:start_stream` → calls LLM     |
  |             |                 |                     | `{:response_end, text}` → saves |
  | `:failed`   | returns chat    | `{:error, :busy}`   | `:state_timeout` → retries      |

  ## Error classification

  Stream failures are classified via `handle_stream_error/2`:

  | Error shape                          | Source                     | Retryable?        | Delay                            |
  |--------------------------------------|----------------------------|-------------------|----------------------------------|
  | `%OpenAI.API.ErrorResponse{}`        | HTTP 4xx/5xx from OpenAI   | `retryable?/1`    | `retry_delay_seconds/1` (5–300s) |
  | `%_{__exception__: true}`            | Req transport error        | always            | 10 s                             |
  | `String.t()`                         | SSE `error` / `response.failed` | never       | —                                |

  Up to `3` retries are attempted before the error is treated as permanent
  and the session returns to `:idle`.
  """

  @behaviour :gen_statem

  alias MusicLibrary.{Chats, Chats.SessionRegistry}
  alias OpenAI.API.ErrorResponse

  require Logger

  @max_retries 3

  defstruct new_chat_params: %{},
            chat_id: nil,
            chat: nil,
            instructions: "",
            retry_count: 0

  def start_link(params) do
    :gen_statem.start_link(via(params.chat_id), __MODULE__, params, [])
  end

  def get_history(chat_id) do
    :gen_statem.call(via(chat_id), :get_history)
  end

  def send_message(chat_id, message_text) do
    :gen_statem.call(via(chat_id), {:send_message, message_text})
  end

  def status(chat_id) do
    :gen_statem.call(via(chat_id), :status)
  end

  @impl :gen_statem
  def callback_mode, do: :state_functions

  @impl :gen_statem
  def init(params) do
    chat_id = Map.fetch!(params, :chat_id)
    instructions = Map.fetch!(params, :instructions)
    new_chat_params = Map.get(params, :new_chat_params, %{})

    data = %__MODULE__{
      new_chat_params: new_chat_params,
      chat_id: chat_id,
      chat: Chats.get_chat(chat_id),
      instructions: instructions,
      retry_count: 0
    }

    {:ok, :idle, data}
  end

  def idle({:call, from}, :get_history, data) do
    {:keep_state, data, [{:reply, from, data.chat}]}
  end

  def idle({:call, from}, {:send_message, message_text}, data) when is_struct(data.chat) do
    message_attrs = %{role: "user", content: message_text}

    case Chats.add_message(data.chat, message_attrs) do
      {:ok, message} ->
        data = %{data | chat: Chats.get_chat(data.chat_id), retry_count: 0}

        {:next_state, :streaming, data,
         [{:reply, from, {:ok, message}}, {:next_event, :internal, :start_stream}]}

      error ->
        {:keep_state, data, [{:reply, from, error}]}
    end
  end

  def idle({:call, from}, {:send_message, message_text}, data) when is_nil(data.chat) do
    message_attrs = %{role: "user", content: message_text}

    chat_attrs = %{
      id: data.chat_id,
      entity: data.new_chat_params.entity,
      musicbrainz_id: data.new_chat_params.musicbrainz_id
    }

    case Chats.create_chat_with_message(chat_attrs, message_attrs) do
      {:ok, chat} ->
        [message] = chat.messages

        {:next_state, :streaming, %{data | chat: chat, retry_count: 0},
         [{:reply, from, {:ok, message}}, {:next_event, :internal, :start_stream}]}

      error ->
        {:keep_state, data, [{:reply, from, error}]}
    end
  end

  def idle({:call, from}, :status, _data) do
    {:keep_state_and_data, [{:reply, from, :idle}]}
  end

  def idle(_event_type, _event_content, _data) do
    :keep_state_and_data
  end

  def streaming({:call, from}, :get_history, data) do
    {:keep_state, data, [{:reply, from, data.chat}]}
  end

  def streaming({:call, from}, {:send_message, _message_text}, data) do
    {:keep_state, data, [{:reply, from, {:error, :busy}}]}
  end

  def streaming(:internal, :start_stream, data) do
    stream_messages = Enum.map(data.chat.messages, &%{role: &1.role, content: &1.content})

    case OpenAI.chat_stream(stream_messages,
           on_chunk: fn _chunk -> :ok end,
           instructions: data.instructions
         ) do
      {:ok, response} ->
        {:keep_state, data, [{:next_event, :internal, {:response_end, response}}]}

      {:error, reason} ->
        handle_stream_error(reason, data)
    end
  end

  def streaming(:internal, {:response_end, response}, data) do
    message_attrs = %{role: "assistant", content: response}

    Chats.add_message(data.chat, message_attrs)

    data = %{data | chat: Chats.get_chat(data.chat_id), retry_count: 0}
    {:next_state, :idle, data}
  end

  def streaming({:call, from}, :status, _data) do
    {:keep_state_and_data, [{:reply, from, :streaming}]}
  end

  def streaming(_event_type, _event_content, _data) do
    :keep_state_and_data
  end

  def failed(:state_timeout, :retry, data) do
    {:next_state, :streaming, data, [{:next_event, :internal, :start_stream}]}
  end

  def failed({:call, from}, :get_history, data) do
    {:keep_state, data, [{:reply, from, data.chat}]}
  end

  def failed({:call, from}, {:send_message, _message_text}, data) do
    {:keep_state, data, [{:reply, from, {:error, :busy}}]}
  end

  def failed({:call, from}, :status, _data) do
    {:keep_state_and_data, [{:reply, from, :failed}]}
  end

  def failed(_event_type, _event_content, _data) do
    :keep_state_and_data
  end

  defp handle_stream_error(reason, data) do
    if stream_error_retryable?(reason) and data.retry_count < @max_retries do
      delay = stream_error_retry_delay(reason)
      data = %{data | retry_count: data.retry_count + 1}

      Logger.warning(
        "Chat stream failed (retry #{data.retry_count}/#{@max_retries} in #{delay}s): #{inspect(reason)}"
      )

      {:next_state, :failed, data, [{:state_timeout, delay * 1000, :retry}]}
    else
      Logger.error("Chat stream failed permanently: #{inspect(reason)}")
      {:next_state, :idle, %{data | retry_count: 0}}
    end
  end

  defp stream_error_retryable?(%ErrorResponse{} = error), do: ErrorResponse.retryable?(error)
  defp stream_error_retryable?(%_{__exception__: true}), do: true
  defp stream_error_retryable?(_error), do: false

  defp stream_error_retry_delay(%ErrorResponse{} = error),
    do: ErrorResponse.retry_delay_seconds(error)

  defp stream_error_retry_delay(_exception), do: 10

  defp via(chat_id) do
    {:via, Registry, {SessionRegistry, chat_id}}
  end
end
