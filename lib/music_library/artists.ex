defmodule MusicLibrary.Artists do
  import Ecto.Query, warn: false
  alias MusicLibrary.Repo

  alias MusicLibrary.Records.ArtistRecord

  def get_artist!(musicbrainz_id) do
    q =
      from ar in ArtistRecord,
        where: ar.musicbrainz_id == ^musicbrainz_id,
        limit: 1,
        select: ar.artist

    Repo.one!(q)
  end

  def get_similar_artists(artist) do
    case LastFm.get_similar_artists(artist.musicbrainz_id, artist.name) do
      {:ok, artists} ->
        all_artist_ids = get_all_artist_ids()

        {:ok,
         Enum.filter(artists, fn a ->
           MapSet.member?(all_artist_ids, a.musicbrainz_id)
         end)}

      error ->
        error
    end
  end

  def get_all_artist_ids do
    q = from ar in ArtistRecord, distinct: true, select: ar.musicbrainz_id

    q |> Repo.all() |> MapSet.new()
  end
end
