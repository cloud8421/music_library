defmodule MusicLibrary.Repo.Migrations.RemoveUniqueIndexFromRecords do
  use Ecto.Migration

  def change do
    drop unique_index(:records, [:musicbrainz_id, :format])
  end
end
