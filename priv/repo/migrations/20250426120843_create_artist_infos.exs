defmodule MusicLibrary.Repo.Migrations.CreateArtistInfos do
  use Ecto.Migration

  def change do
    create table(:artist_infos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :musicbrainz_data, :map
      add :discogs_data, :map
      add :image_data, :blob
      add :image_data_hash, :string
      add :image_data_width, :integer

      timestamps(type: :utc_datetime)
    end
  end
end
