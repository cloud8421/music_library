defmodule MusicLibrary.ChatsFixtures do
  @moduledoc false

  alias MusicLibrary.Chats

  def chat_fixture(chat_attrs \\ %{}, message_attrs \\ %{}) do
    chat_attrs = Map.merge(%{entity: :record, musicbrainz_id: Ecto.UUID.generate()}, chat_attrs)
    message_attrs = Map.merge(%{content: "message content", role: "user"}, message_attrs)

    {:ok, chat} = Chats.create_chat_with_message(chat_attrs, message_attrs)
    chat
  end
end
