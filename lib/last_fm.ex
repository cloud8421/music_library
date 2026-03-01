defmodule LastFm do
  alias LastFm.{API, Feed, Refresh, Scrobble, Track, Worker}
  alias MusicLibrary.{BackgroundRepo, Repo}

  def subscribe_to_feed, do: Feed.subscribe()

  def refresh_scrobbled_tracks, do: Refresh.refresh()

  def get_tracks(opts) do
    last_fm_config = last_fm_config()
    API.get_recent_tracks(opts, last_fm_config)
  end

  def lowest_scrobbled_at_uts do
    Repo.aggregate(Track, :min, :scrobbled_at_uts)
  end

  def backfill_scrobbled_tracks do
    to_uts = lowest_scrobbled_at_uts()

    %{"to_uts" => to_uts}
    |> Worker.BackfillScrobbledTracks.new()
    |> BackgroundRepo.insert()
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

  def get_artist_tags(musicbrainz_id, name) do
    last_fm_config = last_fm_config()

    case API.get_artist_tags({:musicbrainz_id, musicbrainz_id}, last_fm_config) do
      {:ok, tags} ->
        {:ok, tags}

      {:error, :invalid_parameters} ->
        # Sometimes the artist cannot be identified with the MusicBrainz ID,
        # because Last.fm doesn't have that information. In that case, we try again with the artist name.
        API.get_artist_tags({:name, name}, last_fm_config)

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

  def api_cooldown, do: last_fm_config().api_cooldown

  defp last_fm_config, do: LastFm.Config.resolve(:music_library)
end
