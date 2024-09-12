defmodule MusicLibrary.Repo.Migrations.CreateArtistsRecords do
  use Ecto.Migration

  def change do
    create table(:artists_records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :artist_id, references(:artists, on_delete: :nothing, type: :binary_id)
      add :record_id, references(:records, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:artists_records, [:artist_id])
    create index(:artists_records, [:record_id])
  end
end
