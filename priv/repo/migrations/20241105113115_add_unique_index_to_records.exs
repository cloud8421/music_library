defmodule MusicLibrary.Repo.Migrations.AddUniqueIndexToRecords do
  use Ecto.Migration

  def change do
    create unique_index(:records, [:musicbrainz_id, :format])
  end
end
