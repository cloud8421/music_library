defmodule MusicLibrary.ScrobbleActivity.Backfill do
  alias MusicLibrary.Artists
  alias MusicLibrary.Repo

  @allowed_artists [
    "IQ",
    "Riverside",
    "Airbag",
    "Arena",
    "Fish",
    "Marillion",
    "Porcupine Tree",
    "Steven Wilson",
    "Gazpacho",
    "Sylvan",
    "Dream Theater",
    "Pink Floyd",
    "Muse",
    "Opeth"
  ]

  def fill_missing_artist_ids do
    name_id_pairs = Artists.name_id_pairs(@allowed_artists)

    Enum.each(name_id_pairs, fn {name, id} ->
      Repo.query(
        """
        UPDATE scrobbled_tracks
        SET artist = json_set(artist, '$.musicbrainz_id', ?)
        WHERE artist ->> '$.name' == ?;
        """,
        [id, name]
      )
    end)
  end
end
