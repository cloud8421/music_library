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

  def get_all_artist_ids do
    q = from ar in ArtistRecord, distinct: true, select: ar.musicbrainz_id

    q |> Repo.all() |> MapSet.new()
  end

  def get_artist_info(artist) do
    last_fm_config = last_fm_config()

    case last_fm_config.api.get_artist_info(
           {:musicbrainz_id, artist.musicbrainz_id},
           last_fm_config
         ) do
      {:ok, info} ->
        {:ok, info}

      {:error, :invalid_parameters} ->
        # Sometimes the artist info cannot be identified with the MusicBrainz ID,
        # because Last.fm doesn't have that information. In that case, we try again with the artist name.
        last_fm_config.api.get_artist_info({:name, artist.name}, last_fm_config)

      error ->
        error
    end
  end

  def get_similar_artists(artist) do
    last_fm_config = last_fm_config()

    case last_fm_config.api.get_similar_artists(
           {:musicbrainz_id, artist.musicbrainz_id},
           last_fm_config
         ) do
      {:ok, info} ->
        {:ok, info}

      {:error, :invalid_parameters} ->
        # Sometimes the artist info cannot be identified with the MusicBrainz ID,
        # because Last.fm doesn't have that information. In that case, we try again with the artist name.
        last_fm_config.api.get_similar_artists({:name, artist.name}, last_fm_config)

      error ->
        error
    end
  end

  defp last_fm_config, do: LastFm.Config.resolve(:music_library)
end
