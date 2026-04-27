defmodule MusicLibrary.Chats.SessionTest do
  use MusicLibrary.DataCase, async: false

  import MusicLibrary.ChatsFixtures

  alias MusicLibrary.Chats.Session

  describe "get_history/1" do
    test "for existing chats" do
      chat = chat_fixture()

      params = %{
        chat_id: chat.id,
        entity: chat.entity,
        musicbrainz_id: chat.musicbrainz_id
      }

      assert {:ok, _pid} = Session.start_link(params)
      assert chat == Session.get_history(chat.id)
    end

    test "for non existing chats" do
      chat_id = Ecto.UUID.generate()

      params = %{
        chat_id: chat_id,
        entity: :record,
        musicbrainz_id: Ecto.UUID.generate()
      }

      assert {:ok, _pid} = Session.start_link(params)
      assert nil == Session.get_history(chat_id)
    end
  end

  describe "send_message/2" do
    test "for existing chats appends the message" do
      chat = chat_fixture()

      params = %{
        chat_id: chat.id,
        entity: chat.entity,
        musicbrainz_id: chat.musicbrainz_id
      }

      assert {:ok, _pid} = Session.start_link(params)
      assert {:ok, message} = Session.send_message(chat.id, "some message")

      assert message.content == "some message"
      assert message.chat_id == chat.id

      updated_chat = Session.get_history(chat.id)

      assert message in updated_chat.messages
    end

    test "for non existing chats creates the chat with the message" do
      chat_id = Ecto.UUID.generate()

      params = %{
        chat_id: chat_id,
        entity: :record,
        musicbrainz_id: Ecto.UUID.generate()
      }

      assert {:ok, _pid} = Session.start_link(params)
      assert {:ok, message} = Session.send_message(chat_id, "some message")

      assert message.content == "some message"
      assert message.chat_id == chat_id

      chat = Session.get_history(chat_id)
      assert [message] == chat.messages
    end
  end
end
