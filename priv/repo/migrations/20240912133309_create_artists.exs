defmodule MusicLibrary.Repo.Migrations.CreateArtists do
  use Ecto.Migration

  def change do
    create table(:artists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :musicbrainz_id, :uuid
      add :image, :string

      timestamps(type: :utc_datetime)
    end
  end
end
