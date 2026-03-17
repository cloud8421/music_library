defmodule MusicLibrary.Repo.Migrations.CreateChats do
  use Ecto.Migration

  def change do
    create table(:chats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :entity, :string, null: false
      add :musicbrainz_id, :uuid, null: false
      add :topic, :string

      timestamps(type: :utc_datetime)
    end

    # Listing chats for a specific entity
    create index(:chats, [:entity, :musicbrainz_id])

    # Ordered listing of chats for a specific entity
    create index(:chats, [:entity, :musicbrainz_id, :updated_at])

    create table(:chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false
      add :content, :text, null: false
      add :position, :integer, null: false

      add :chat_id, references(:chats, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    # Ordered listing of messages within a chat
    create index(:chat_messages, [:chat_id, :position])
  end
end
