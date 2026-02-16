defmodule MusicLibrary.Repo.Migrations.AddScrobbledTracksIndexes do
  use Ecto.Migration

  def change do
    # Helps GROUP BY in get_top_albums / get_top_albums_by_days
    # Also helps the WHERE json_extract(album, '$.title') != '' filter
    execute(
      """
      CREATE INDEX scrobbled_tracks_album_title_artist_name_index
        ON scrobbled_tracks(
          json_extract(album, '$.title'),
          json_extract(artist, '$.name')
        )
      """,
      "DROP INDEX scrobbled_tracks_album_title_artist_name_index"
    )

    # Helps GROUP BY in get_top_artists / get_top_artists_by_days
    execute(
      """
      CREATE INDEX scrobbled_tracks_artist_name_index
        ON scrobbled_tracks(json_extract(artist, '$.name'))
      """,
      "DROP INDEX scrobbled_tracks_artist_name_index"
    )

    # Helps LEFT JOIN to collection/wishlist subqueries
    # (join condition: cr.release_id == json_extract(t.album, '$.musicbrainz_id'))
    execute(
      """
      CREATE INDEX scrobbled_tracks_album_musicbrainz_id_index
        ON scrobbled_tracks(json_extract(album, '$.musicbrainz_id'))
      """,
      "DROP INDEX scrobbled_tracks_album_musicbrainz_id_index"
    )

    # Helps LEFT JOIN to artist_infos
    # (join condition: ai.id == json_extract(t.artist, '$.musicbrainz_id'))
    execute(
      """
      CREATE INDEX scrobbled_tracks_artist_musicbrainz_id_index
        ON scrobbled_tracks(json_extract(artist, '$.musicbrainz_id'))
      """,
      "DROP INDEX scrobbled_tracks_artist_musicbrainz_id_index"
    )
  end
end
