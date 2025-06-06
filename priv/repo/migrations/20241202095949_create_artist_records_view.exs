defmodule MusicLibrary.Repo.Migrations.CreateArtistRecordsView do
  use Ecto.Migration

  def up do
    execute """
    CREATE VIEW artist_records AS
      SELECT json_each.value ->> '$.musicbrainz_id' AS musicbrainz_id, 
      records.id AS record_id,
      json_each.value as artist
      FROM records, 
      json_each(records.artists)
    """
  end

  def down do
    execute "DROP VIEW artist_records"
  end
end
