defmodule MusicLibrary.ScrobbleActivity.Backfill do
  alias MusicLibrary.Artists
  alias MusicLibrary.Repo

  @allowed_artists [
    "Airbag",
    "Arena",
    "Dream Theater",
    "Fish",
    "Gazpacho",
    "IQ",
    "Marillion",
    "Meer",
    "Muse",
    "Opeth",
    "Pink Floyd",
    "Porcupine Tree",
    "Riverside",
    "Steven Wilson",
    "Sylvan"
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
