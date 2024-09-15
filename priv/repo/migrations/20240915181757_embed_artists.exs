defmodule MusicLibrary.Repo.Migrations.EmbedArtists do
  use Ecto.Migration

  def change do
    drop table(:artists_records)
    drop table(:artists)

    alter table(:records) do
      add :artists, :map
    end
  end
end
