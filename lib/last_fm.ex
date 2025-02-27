defmodule LastFm do
  alias LastFm.API

  def get_artist_info(musicbrainz_id, name) do
    last_fm_config = last_fm_config()

    case API.get_artist_info(
           {:musicbrainz_id, musicbrainz_id},
           last_fm_config
         ) do
      {:ok, info} ->
        {:ok, info}

      {:error, :invalid_parameters} ->
        # Sometimes the artist info cannot be identified with the MusicBrainz ID,
        # because Last.fm doesn't have that information. In that case, we try again with the artist name.
        API.get_artist_info({:name, name}, last_fm_config)

      error ->
        error
    end
  end

  def get_similar_artists(musicbrainz_id, name) do
    last_fm_config = last_fm_config()

    case API.get_similar_artists(
           {:musicbrainz_id, musicbrainz_id},
           last_fm_config
         ) do
      {:ok, info} ->
        {:ok, info}

      {:error, :invalid_parameters} ->
        # Sometimes the artist info cannot be identified with the MusicBrainz ID,
        # because Last.fm doesn't have that information. In that case, we try again with the artist name.
        API.get_similar_artists({:name, name}, last_fm_config)

      error ->
        error
    end
  end

  defp last_fm_config, do: LastFm.Config.resolve(:music_library)
end
