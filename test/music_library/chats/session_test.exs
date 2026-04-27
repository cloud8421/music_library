defmodule MusicLibrary.Chats.SessionTest do
  use MusicLibrary.DataCase, async: false

  import MusicLibrary.ChatsFixtures

  alias MusicLibrary.Chats.Session

  describe "get_history/1" do
    test "for existing chats" do
      chat = chat_fixture()

      assert {:ok, _pid} = Session.start_link(:record, chat.id)
      assert chat == Session.get_history(chat.id)
    end

    test "for non existing chats" do
      chat_id = Ecto.UUID.generate()

      assert {:ok, _pid} = Session.start_link(:record, chat_id)
      assert nil == Session.get_history(chat_id)
    end
  end
end
