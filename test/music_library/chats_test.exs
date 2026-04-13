defmodule MusicLibrary.ChatsTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Chats
  alias MusicLibrary.Chats.Chat

  @musicbrainz_id Ecto.UUID.generate()

  defp create_chat(_context) do
    {:ok, chat} =
      Chats.create_chat_with_message(
        %{entity: :record, musicbrainz_id: @musicbrainz_id},
        %{role: "user", content: "Tell me about this album"}
      )

    %{chat: chat}
  end

  describe "count_chats/2" do
    test "returns 0 when no chats exist" do
      assert Chats.count_chats(:record, Ecto.UUID.generate()) == 0
    end

    test "returns the number of chats for an entity" do
      Chats.create_chat_with_message(
        %{entity: :record, musicbrainz_id: @musicbrainz_id},
        %{role: "user", content: "First chat"}
      )

      Chats.create_chat_with_message(
        %{entity: :record, musicbrainz_id: @musicbrainz_id},
        %{role: "user", content: "Second chat"}
      )

      assert Chats.count_chats(:record, @musicbrainz_id) == 2
    end

    test "does not count chats for different entity" do
      Chats.create_chat_with_message(
        %{entity: :record, musicbrainz_id: @musicbrainz_id},
        %{role: "user", content: "A chat"}
      )

      assert Chats.count_chats(:artist, @musicbrainz_id) == 0
    end

    test "counts collection chats" do
      Chats.create_chat_with_message(
        %{entity: :collection, musicbrainz_id: Chats.collection_musicbrainz_id()},
        %{role: "user", content: "Tell me about my collection"}
      )

      assert Chats.count_chats(:collection, Chats.collection_musicbrainz_id()) == 1
    end
  end

  describe "list_chats/2" do
    setup [:create_chat]

    test "returns empty list when no chats exist" do
      assert Chats.list_chats(:record, Ecto.UUID.generate()) == []
    end

    test "returns chats for entity with message count", %{chat: chat} do
      chats = Chats.list_chats(:record, @musicbrainz_id)

      assert [listed_chat] = chats
      assert listed_chat.id == chat.id
      assert listed_chat.message_count == 1
    end

    test "does not return chats for different entity", %{chat: _chat} do
      assert Chats.list_chats(:artist, @musicbrainz_id) == []
    end

    test "orders by updated_at desc", %{chat: first_chat} do
      {:ok, second_chat} =
        Chats.create_chat_with_message(
          %{entity: :record, musicbrainz_id: @musicbrainz_id},
          %{role: "user", content: "Another question"}
        )

      chats = Chats.list_chats(:record, @musicbrainz_id)
      assert [%{id: id1}, %{id: id2}] = chats
      assert id1 == second_chat.id
      assert id2 == first_chat.id
    end
  end

  describe "get_chat!/1" do
    setup [:create_chat]

    test "returns chat with preloaded messages", %{chat: chat} do
      found = Chats.get_chat!(chat.id)

      assert found.id == chat.id
      assert found.entity == :record
      assert [message] = found.messages
      assert message.role == "user"
      assert message.content == "Tell me about this album"
    end

    test "raises for nonexistent chat" do
      assert_raise Ecto.NoResultsError, fn ->
        Chats.get_chat!(Ecto.UUID.generate())
      end
    end
  end

  describe "create_chat_with_message/2" do
    test "creates chat with first message" do
      assert {:ok, chat} =
               Chats.create_chat_with_message(
                 %{entity: :artist, musicbrainz_id: @musicbrainz_id},
                 %{role: "user", content: "Who is this artist?"}
               )

      assert chat.entity == :artist
      assert chat.musicbrainz_id == @musicbrainz_id
      assert chat.topic == "Who is this artist?"
      assert [message] = chat.messages
      assert message.role == "user"
      assert message.position == 0
    end

    test "truncates topic to 80 characters" do
      long_message = String.duplicate("a", 200)

      assert {:ok, chat} =
               Chats.create_chat_with_message(
                 %{entity: :record, musicbrainz_id: @musicbrainz_id},
                 %{role: "user", content: long_message}
               )

      assert String.length(chat.topic) == 80
    end

    test "returns error for invalid chat attrs" do
      assert {:error, _changeset} =
               Chats.create_chat_with_message(
                 %{},
                 %{role: "user", content: "Hello"}
               )
    end

    test "creates chat with collection entity" do
      assert {:ok, chat} =
               Chats.create_chat_with_message(
                 %{entity: :collection, musicbrainz_id: Chats.collection_musicbrainz_id()},
                 %{role: "user", content: "What prog rock do I have?"}
               )

      assert chat.entity == :collection
      assert chat.musicbrainz_id == Chats.collection_musicbrainz_id()
      assert chat.topic == "What prog rock do I have?"
    end
  end

  describe "collection_musicbrainz_id/0" do
    test "returns a valid UUID" do
      id = Chats.collection_musicbrainz_id()
      assert {:ok, _} = Ecto.UUID.cast(id)
    end
  end

  describe "add_message/2" do
    setup [:create_chat]

    test "adds message with auto-computed position", %{chat: chat} do
      assert {:ok, message} =
               Chats.add_message(chat, %{role: "assistant", content: "Here's what I know..."})

      assert message.role == "assistant"
      assert message.position == 1
      assert message.chat_id == chat.id
    end

    test "increments position for each message", %{chat: chat} do
      {:ok, _} = Chats.add_message(chat, %{role: "assistant", content: "Response 1"})
      {:ok, msg} = Chats.add_message(chat, %{role: "user", content: "Follow up"})

      assert msg.position == 2
    end

    test "touches chat updated_at", %{chat: chat} do
      # Force a different timestamp by manually setting the original earlier
      Repo.update_all(
        from(c in Chat, where: c.id == ^chat.id),
        set: [updated_at: ~U[2025-01-01 00:00:00Z]]
      )

      {:ok, _} = Chats.add_message(chat, %{role: "assistant", content: "Response"})

      updated_chat = Chats.get_chat!(chat.id)
      assert DateTime.compare(updated_chat.updated_at, ~U[2025-01-01 00:00:00Z]) == :gt
    end
  end

  describe "delete_chat/1" do
    setup [:create_chat]

    test "deletes chat and its messages", %{chat: chat} do
      assert {:ok, _} = Chats.delete_chat(chat)

      assert_raise Ecto.NoResultsError, fn ->
        Chats.get_chat!(chat.id)
      end
    end
  end
end
