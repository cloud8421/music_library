defmodule LastFm do
  alias LastFm.{API, Feed, Refresh, Scrobble}

  def get_scrobbled_tracks, do: Feed.all_tracks()

  def subscribe_to_feed, do: Feed.subscribe()

  def refresh_scrobbled_tracks, do: Refresh.refresh()

  def get_tracks(to_uts) do
    last_fm_config = last_fm_config()
    API.get_recent_tracks(to_uts, last_fm_config)
  end

  def get_artist_info(musicbrainz_id, name) do
    last_fm_config = last_fm_config()

    case API.get_artist_info({:musicbrainz_id, musicbrainz_id}, last_fm_config) do
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

    case API.get_similar_artists({:musicbrainz_id, musicbrainz_id}, last_fm_config) do
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

  def get_session(token) do
    last_fm_config = last_fm_config()

    API.get_session(token, last_fm_config)
  end

  def scrobble(scrobbles, session_key) do
    last_fm_config = last_fm_config()

    scrobbles
    |> Enum.map(&Scrobble.encode/1)
    |> API.scrobble(session_key, last_fm_config)
  end

  def auth_url do
    last_fm_config = last_fm_config()
    "https://www.last.fm/api/auth/?api_key=" <> last_fm_config.api_key
  end

  defp last_fm_config, do: LastFm.Config.resolve(:music_library)
end
