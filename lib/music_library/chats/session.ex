defmodule MusicLibrary.Chats.Session do
  @moduledoc false

  use GenServer

  alias MusicLibrary.{Chats, Chats.SessionRegistry}

  defstruct new_chat_params: %{},
            chat_id: nil,
            chat: nil,
            instructions: "",
            current_chunk: ""

  def start_link(params) do
    GenServer.start_link(__MODULE__, params, name: via(params.chat_id))
  end

  def get_history(chat_id) do
    GenServer.call(via(chat_id), :get_history)
  end

  def send_message(chat_id, message_text) do
    GenServer.call(via(chat_id), {:send_message, message_text})
  end

  @impl true
  def init(params) do
    chat_id = Map.fetch!(params, :chat_id)
    instructions = Map.fetch!(params, :instructions)
    new_chat_params = Map.get(params, :new_chat_params, %{})

    state = %__MODULE__{
      new_chat_params: new_chat_params,
      chat_id: chat_id,
      chat: Chats.get_chat(chat_id),
      instructions: instructions
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_history, _from, state) do
    {:reply, state.chat, state}
  end

  @impl true
  def handle_call({:send_message, message_text}, _from, state) when is_struct(state.chat) do
    message_attrs = %{
      role: "user",
      content: message_text
    }

    case Chats.add_message(state.chat, message_attrs) do
      {:ok, message} ->
        state = %{state | chat: Chats.get_chat(state.chat_id)}
        {:reply, {:ok, message}, state, {:continue, :ask_llm}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:send_message, message_text}, _from, state) when is_nil(state.chat) do
    message_attrs = %{
      role: "user",
      content: message_text
    }

    chat_attrs = %{
      id: state.chat_id,
      entity: state.new_chat_params.entity,
      musicbrainz_id: state.new_chat_params.musicbrainz_id
    }

    case Chats.create_chat_with_message(chat_attrs, message_attrs) do
      {:ok, chat} ->
        [message] = chat.messages
        {:reply, {:ok, message}, %{state | chat: chat}, {:continue, :ask_llm}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_continue(:ask_llm, state) do
    stream_messages = Enum.map(state.chat.messages, &%{role: &1.role, content: &1.content})

    # We get fragments for every on_chunk call
    # When the function returns, it's done
    OpenAI.chat_stream(stream_messages,
      on_chunk: fn chunk -> send(self(), {:message_chunk, chunk}) end,
      instructions: state.instructions
    )

    send(self(), :message_done)

    {:noreply, state}
  end

  @impl true
  def handle_info({:message_chunk, chunk}, state) do
    state = %{state | current_chunk: state.current_chunk <> chunk}
    {:noreply, state}
  end

  def handle_info(:message_done, state) do
    message_attrs = %{
      role: "assistant",
      content: state.current_chunk
    }

    Chats.add_message(state.chat, message_attrs)

    state = %{state | current_chunk: "", chat: Chats.get_chat(state.chat_id)}
    {:noreply, state}
  end

  defp via(chat_id) do
    {:via, Registry, {SessionRegistry, chat_id}}
  end
end
