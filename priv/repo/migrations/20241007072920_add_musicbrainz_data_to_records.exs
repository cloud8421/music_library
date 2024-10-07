defmodule MusicLibrary.Repo.Migrations.AddMusicbrainzDataToRecords do
  use Ecto.Migration

  def change do
    alter table(:records) do
      add :musicbrainz_data, :map
    end
  end
end
