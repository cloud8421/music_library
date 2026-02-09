defmodule MusicLibrary.Repo.Migrations.AddWikipediaDataToArtistInfos do
  use Ecto.Migration

  def change do
    alter table(:artist_infos) do
      add :wikipedia_data, :map
    end
  end
end
