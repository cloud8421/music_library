defmodule MusicLibrary.Repo.Migrations.AddLastfmDataToArtistInfos do
  use Ecto.Migration

  def change do
    alter table(:artist_infos) do
      add :lastfm_data, :map, default: %{}
    end
  end
end
