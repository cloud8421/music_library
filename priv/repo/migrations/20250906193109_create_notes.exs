defmodule MusicLibrary.Repo.Migrations.CreateNotes do
  use Ecto.Migration

  def change do
    create table(:notes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :entity, :string, null: false
      add :musicbrainz_id, :uuid, null: false
      add :content, :string

      timestamps(type: :utc_datetime)
    end

    create index(:notes, [:entity, :musicbrainz_id], unique: true)
  end
end
