defmodule MusicLibrary.Repo.Migrations.AddMusicbrainzIdIndexToArtists do
  use Ecto.Migration

  def change do
    create unique_index(:artists, [:musicbrainz_id])
  end
end
