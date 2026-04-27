defmodule MusicLibrary.Chats.Session do
  @moduledoc false

  use GenServer

  alias MusicLibrary.{Chats.Chat, Chats.SessionRegistry, Repo}

  defstruct entity: nil,
            chat_id: nil,
            chat: nil

  def start_link(entity, chat_id) do
    GenServer.start_link(__MODULE__, {entity, chat_id}, name: via(chat_id))
  end

  def get_history(chat_id) do
    GenServer.call(via(chat_id), :get_history)
  end

  @impl true
  def init({entity, chat_id}) do
    {:ok, %__MODULE__{entity: entity, chat_id: chat_id}, {:continue, :load_existing_chat}}
  end

  @impl true
  def handle_call(:get_history, _from, state) do
    {:reply, state.chat, state}
  end

  @impl true
  def handle_continue(:load_existing_chat, state) do
    {:noreply, %{state | chat: load_chat(state.chat_id)}}
  end

  defp load_chat(chat_id) do
    Chat
    |> Repo.get(chat_id)
    |> Repo.preload(:messages)
  end

  defp via(chat_id) do
    {:via, Registry, {SessionRegistry, chat_id}}
  end
end
