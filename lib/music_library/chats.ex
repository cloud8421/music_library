defmodule MusicLibrary.Chats do
  @moduledoc """
  Persistent storage for AI chat conversations about records, artists, and the collection.
  """

  import Ecto.Query, warn: false

  alias MusicLibrary.Chats.{Chat, Message}
  alias MusicLibrary.Repo

  @collection_musicbrainz_id "00000000-0000-0000-0000-000000000000"

  @spec collection_musicbrainz_id() :: String.t()
  def collection_musicbrainz_id, do: @collection_musicbrainz_id

  @spec list_chats(atom(), String.t()) :: [Chat.t()]
  def list_chats(entity, musicbrainz_id) do
    message_count_query =
      from(m in Message,
        where: m.chat_id == parent_as(:chat).id,
        select: count(m.id)
      )

    from(c in Chat,
      as: :chat,
      where: c.entity == ^entity and c.musicbrainz_id == ^musicbrainz_id,
      order_by: [desc: c.updated_at],
      select_merge: %{message_count: subquery(message_count_query)}
    )
    |> Repo.all()
  end

  @spec count_chats(atom(), String.t()) :: non_neg_integer()
  def count_chats(entity, musicbrainz_id) do
    from(c in Chat,
      where: c.entity == ^entity and c.musicbrainz_id == ^musicbrainz_id
    )
    |> Repo.aggregate(:count)
  end

  @spec has_any_chats?(atom(), String.t()) :: boolean()
  def has_any_chats?(entity, musicbrainz_id) do
    from(c in Chat,
      where: c.entity == ^entity and c.musicbrainz_id == ^musicbrainz_id
    )
    |> Repo.exists?()
  end

  @spec get_chat!(String.t()) :: Chat.t()
  def get_chat!(id) do
    Chat
    |> Repo.get!(id)
    |> Repo.preload(:messages)
  end

  @spec create_chat_with_message(map(), map()) ::
          {:ok, Chat.t()} | {:error, Ecto.Changeset.t()}
  def create_chat_with_message(chat_attrs, message_attrs) do
    topic =
      message_attrs
      |> Map.get(:content, "")
      |> String.trim()
      |> String.slice(0, 80)

    Repo.transaction(fn ->
      chat_attrs = Map.put(chat_attrs, :topic, topic)

      with {:ok, chat} <- %Chat{} |> Chat.changeset(chat_attrs) |> Repo.insert(),
           message_attrs = Map.merge(message_attrs, %{position: 0}),
           {:ok, _message} <-
             %Message{chat_id: chat.id}
             |> Message.changeset(message_attrs)
             |> Repo.insert() do
        Repo.preload(chat, :messages)
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @spec add_message(Chat.t(), map()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def add_message(%Chat{} = chat, attrs) do
    next_position =
      from(m in Message,
        where: m.chat_id == ^chat.id,
        select: coalesce(max(m.position), -1)
      )
      |> Repo.one!()
      |> Kernel.+(1)

    attrs = Map.put(attrs, :position, next_position)

    result =
      %Message{chat_id: chat.id}
      |> Message.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, message} ->
        touch_chat(chat)
        {:ok, message}

      error ->
        error
    end
  end

  @spec delete_chat(Chat.t()) :: {:ok, Chat.t()} | {:error, Ecto.Changeset.t()}
  def delete_chat(%Chat{} = chat) do
    Repo.delete(chat)
  end

  defp touch_chat(chat) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    from(c in Chat, where: c.id == ^chat.id)
    |> Repo.update_all(set: [updated_at: now])
  end
end
