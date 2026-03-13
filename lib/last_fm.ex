defmodule LastFm do
  @moduledoc """
  Last.fm API facade for scrobbling and listening history.
  """

  alias LastFm.{API, Feed, Refresh, Scrobble, Track, Worker}
  alias MusicLibrary.{BackgroundRepo, Repo}

  @spec subscribe_to_feed() :: :ok
  def subscribe_to_feed, do: Feed.subscribe()

  @spec refresh_scrobbled_tracks() :: :ok | {:error, term()}
  def refresh_scrobbled_tracks, do: Refresh.refresh()

  @spec get_tracks(keyword()) :: {:ok, [Track.t()]} | {:error, term()}
  def get_tracks(opts) do
    last_fm_config = last_fm_config()
    API.get_recent_tracks(opts, last_fm_config)
  end

  @spec lowest_scrobbled_at_uts() :: integer() | nil
  def lowest_scrobbled_at_uts do
    Repo.aggregate(Track, :min, :scrobbled_at_uts)
  end

  @spec backfill_scrobbled_tracks() :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def backfill_scrobbled_tracks do
    to_uts = lowest_scrobbled_at_uts()

    %{"to_uts" => to_uts}
    |> Worker.BackfillScrobbledTracks.new()
    |> BackgroundRepo.insert()
  end

  @spec get_artist_info(String.t(), String.t()) :: {:ok, LastFm.Artist.t()} | {:error, term()}
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

  @spec get_similar_artists(String.t(), String.t()) ::
          {:ok, [LastFm.Artist.t()]} | {:error, term()}
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

  @spec get_artist_tags(String.t(), String.t()) ::
          {:ok, [{String.t(), integer()}]} | {:error, term()}
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

  @spec get_session(String.t()) :: {:ok, LastFm.Session.t()} | {:error, term()}
  def get_session(token) do
    last_fm_config = last_fm_config()

    API.get_session(token, last_fm_config)
  end

  @spec scrobble([Scrobble.t()], String.t()) :: {:ok, map()} | {:error, term()}
  def scrobble(scrobbles, session_key) do
    last_fm_config = last_fm_config()

    scrobbles
    |> Enum.map(&Scrobble.encode/1)
    |> API.scrobble(session_key, last_fm_config)
  end

  @spec auth_url() :: String.t()
  def auth_url do
    last_fm_config = last_fm_config()
    "https://www.last.fm/api/auth/?api_key=" <> last_fm_config.api_key
  end

  defp last_fm_config, do: LastFm.Config.resolve(:music_library)
end
