defmodule MusicLibrary.Chats.Session do
  @moduledoc false

  @behaviour :gen_statem

  alias MusicLibrary.{Chats, Chats.SessionRegistry}

  defstruct new_chat_params: %{},
            chat_id: nil,
            chat: nil,
            instructions: ""

  def start_link(params) do
    :gen_statem.start_link(via(params.chat_id), __MODULE__, params, [])
  end

  def get_history(chat_id) do
    :gen_statem.call(via(chat_id), :get_history)
  end

  def send_message(chat_id, message_text) do
    :gen_statem.call(via(chat_id), {:send_message, message_text})
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
      instructions: instructions
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
        data = %{data | chat: Chats.get_chat(data.chat_id)}

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

        {:next_state, :streaming, %{data | chat: chat},
         [{:reply, from, {:ok, message}}, {:next_event, :internal, :start_stream}]}

      error ->
        {:keep_state, data, [{:reply, from, error}]}
    end
  end

  def idle(_event_type, _event_content, data) do
    {:keep_state, data}
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
        {:keep_state, data, {:next_event, :internal, {:response_end, response}}}

      {:error, _reason} ->
        # The stream has failed. An improvement here is to look at the failure
        # reason, determine if it's possible to retry (and when), switch to a
        # "failed" state and then if possible retry automatically.
        {:next_state, :idle, data}
    end
  end

  def streaming(:internal, {:response_end, response}, data) do
    message_attrs = %{role: "assistant", content: response}

    Chats.add_message(data.chat, message_attrs)

    data = %{data | chat: Chats.get_chat(data.chat_id)}
    {:next_state, :idle, data}
  end

  def streaming(_event_type, _event_content, data) do
    {:keep_state, data}
  end

  defp via(chat_id) do
    {:via, Registry, {SessionRegistry, chat_id}}
  end
end
