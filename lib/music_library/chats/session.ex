defmodule MusicLibrary.Chats.Session do
  @moduledoc false

  use GenServer

  alias MusicLibrary.{Chats, Chats.SessionRegistry}

  defstruct chat_params: %{},
            chat: nil

  def start_link(chat_params) do
    GenServer.start_link(__MODULE__, chat_params, name: via(chat_params.chat_id))
  end

  def get_history(chat_id) do
    GenServer.call(via(chat_id), :get_history)
  end

  def send_message(chat_id, message_text) do
    GenServer.call(via(chat_id), {:send_message, message_text})
  end

  @impl true
  def init(chat_params) do
    {:ok, %__MODULE__{chat_params: chat_params}, {:continue, :load_existing_chat}}
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
        {:reply, {:ok, message}, state, {:continue, :load_existing_chat}}

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
      id: state.chat_params.chat_id,
      entity: state.chat_params.entity,
      musicbrainz_id: state.chat_params.musicbrainz_id
    }

    case Chats.create_chat_with_message(chat_attrs, message_attrs) do
      {:ok, chat} ->
        [message] = chat.messages
        {:reply, {:ok, message}, %{state | chat: chat}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_continue(:load_existing_chat, state) do
    {:noreply, %{state | chat: Chats.get_chat(state.chat_params.chat_id)}}
  end

  defp via(chat_id) do
    {:via, Registry, {SessionRegistry, chat_id}}
  end
end
