defmodule MusicLibrary.ScrobbleActivity do
  import Ecto.Query

  alias LastFm.{Scrobble, Track}
  alias MusicBrainz.Release
  alias MusicLibrary.{Artists, Collection, Repo, Secrets, Wishlist}

  def can_scrobble? do
    Secrets.get("last_fm_session_key") !== nil
  end

  def scrobble_release(release_with_tracks, opts) when is_list(opts) do
    case Enum.sort(opts) do
      [finished_at: _, started_at: _] ->
        raise ArgumentError, """
        Cannot scobble a release with both started_at and finished_at.
          Remove either of them.
        """

      [started_at: started_at] ->
        scrobble_release(release_with_tracks, {:started_at, started_at})

      [finished_at: finished_at] ->
        scrobble_release(release_with_tracks, {:finished_at, finished_at})
    end
  end

  def scrobble_release(release_with_tracks, {:finished_at, finished_at}) do
    release_duration = Release.release_duration(release_with_tracks)
    started_at = DateTime.add(finished_at, -release_duration, :millisecond)
    scrobble_release(release_with_tracks, {:started_at, started_at})
  end

  def scrobble_release(release_with_tracks, {:started_at, started_at}) do
    session_key = Secrets.get!("last_fm_session_key").value

    {scrobbles, _finished_at} =
      release_with_tracks
      |> MusicBrainz.Release.tracks()
      |> to_scrobbles(release_with_tracks, started_at)

    LastFm.scrobble(scrobbles, session_key)
  end

  def scrobble_medium(number, release_with_tracks, opts) when is_list(opts) do
    case Enum.sort(opts) do
      [finished_at: _, started_at: _] ->
        raise ArgumentError, """
        Cannot scobble a medium with both started_at and finished_at.
          Remove either of them.
        """

      [started_at: started_at] ->
        scrobble_medium(number, release_with_tracks, {:started_at, started_at})

      [finished_at: finished_at] ->
        scrobble_medium(number, release_with_tracks, {:finished_at, finished_at})
    end
  end

  def scrobble_medium(number, release_with_tracks, {:finished_at, finished_at}) do
    medium_duration =
      release_with_tracks.media
      |> Enum.find(fn medium -> medium.number == number end)
      |> Release.medium_duration()

    started_at = DateTime.add(finished_at, -medium_duration, :millisecond)
    scrobble_medium(number, release_with_tracks, {:started_at, started_at})
  end

  def scrobble_medium(number, release_with_tracks, {:started_at, started_at}) do
    session_key = Secrets.get!("last_fm_session_key").value

    medium =
      release_with_tracks.media
      |> Enum.find(fn medium -> medium.number == number end)

    {scrobbles, _finished_at} =
      medium.tracks
      |> to_scrobbles(release_with_tracks, started_at)

    LastFm.scrobble(scrobbles, session_key)
  end

  defp to_scrobbles(tracks, release_with_tracks, started_at) do
    tracks
    |> Enum.map_reduce(started_at, fn track, time ->
      album_artist =
        if release_with_tracks.artists !== track.artists do
          main_artist_name(release_with_tracks.artists)
        end

      time = time |> DateTime.add(track.length, :millisecond)

      scrobble = %Scrobble{
        artist: main_artist_name(track.artists),
        album: release_with_tracks.title,
        album_artist: album_artist,
        track: track.title,
        timestamp: DateTime.to_unix(time)
      }

      {scrobble, time}
    end)
  end

  defp main_artist_name([]), do: nil
  defp main_artist_name([artist | _rest]), do: artist.name

  def from_recent_tracks(recent_tracks, timezone) do
    all_artist_pairs = Artists.get_all_artist_pairs()
    recent_release_ids = recent_release_ids(recent_tracks)
    collected_releases = Collection.collected_releases(recent_release_ids)
    wishlisted_releases = Wishlist.wishlisted_releases(recent_release_ids)

    localized_recent_tracks =
      Enum.map(recent_tracks, fn t ->
        %{
          t
          | scrobbled_at_label: localize_scrobbled_at(t.scrobbled_at_uts, timezone),
            artist: polyfill_artist(t, collected_releases, wishlisted_releases, all_artist_pairs)
        }
      end)

    all_artist_ids = Artists.get_all_artist_ids()
    recent_artist_ids = recent_artist_ids(localized_recent_tracks)
    artist_ids = MapSet.intersection(all_artist_ids, recent_artist_ids)

    recent_albums =
      localized_recent_tracks
      |> Enum.dedup_by(fn t -> t.album end)
      |> Enum.map(fn t ->
        %{
          scrobbled_at_uts: t.scrobbled_at_uts,
          scrobbled_at_label: t.scrobbled_at_label,
          metadata: t.album,
          artist: t.artist,
          cover_url: t.cover_url
        }
      end)

    %{
      localized_recent_tracks: localized_recent_tracks,
      localized_recent_albums: recent_albums,
      collected_releases: collected_releases,
      wishlisted_releases: wishlisted_releases,
      artist_ids: artist_ids
    }
  end

  defp polyfill_artist(track, collected_releases, wishlisted_releases, all_artist_pairs) do
    %{
      track.artist
      | musicbrainz_id:
          find_artist_id(track, collected_releases, wishlisted_releases, all_artist_pairs)
    }
  end

  defguardp has_no_artist_id(track)
            when is_nil(track.artist.musicbrainz_id) or track.artist.musicbrainz_id == ""

  defp find_artist_id(track, collected_releases, wishlisted_releases, all_artist_pairs)
       when has_no_artist_id(track) do
    matched_release =
      Enum.find(collected_releases ++ wishlisted_releases, fn r ->
        r.release_id == track.album.musicbrainz_id
      end)

    record_id = if matched_release, do: matched_release.record_id

    if record_id do
      Enum.find_value(all_artist_pairs, fn pair ->
        if pair.record_id == record_id, do: pair.artist_id
      end)
    end
  end

  defp find_artist_id(track, _collected_releases, _wishlisted_releases, _all_artist_pairs) do
    track.artist.musicbrainz_id
  end

  def localize_scrobbled_at(uts, timezone) do
    ldt =
      uts
      |> DateTime.from_unix!()
      |> DateTime.shift_zone!(timezone)

    Calendar.strftime(ldt, "%d/%m/%Y %X")
  end

  defp recent_release_ids(recent_tracks) do
    recent_tracks
    |> Enum.map(fn t -> t.album.musicbrainz_id end)
    |> Enum.uniq()
    |> Enum.reject(fn musicbrainz_id -> musicbrainz_id == "" end)
  end

  defp recent_artist_ids(recent_tracks) do
    recent_tracks
    |> Enum.map(fn t -> t.artist.musicbrainz_id end)
    |> Enum.uniq()
    |> Enum.reject(fn musicbrainz_id -> musicbrainz_id == "" end)
    |> MapSet.new()
  end

  @doc """
  Gets the top albums by scrobble count for the given number of days.
  Returns a list of maps with album information and play counts.
  """
  def get_top_albums_by_days(days, opts) do
    limit = Keyword.get(opts, :limit, 10)
    current_time = Keyword.get_lazy(opts, :current_time, &DateTime.utc_now/0)
    timezone = Keyword.get(opts, :timezone, &resolve_timezone!/0)

    cutoff_timestamp =
      current_time
      |> DateTime.add(-days, :day)
      |> NaiveDateTime.beginning_of_day()
      |> DateTime.from_naive!(timezone)
      |> DateTime.to_unix()

    query =
      from t in Track,
        where: t.scrobbled_at_uts >= ^cutoff_timestamp,
        group_by: [
          fragment("json_extract(album, '$.title')"),
          fragment("json_extract(artist, '$.name')")
        ],
        select: %{
          album_title: fragment("json_extract(album, '$.title')"),
          artist_name: fragment("json_extract(artist, '$.name')"),
          artist_musicbrainz_id: fragment("json_extract(artist, '$.musicbrainz_id')"),
          play_count: count(t.scrobbled_at_uts),
          cover_url: fragment("max(?)", t.cover_url),
          album_musicbrainz_id: fragment("json_extract(album, '$.musicbrainz_id')")
        },
        order_by: [desc: count(t.scrobbled_at_uts)],
        limit: ^limit

    Repo.all(query)
  end

  @doc """
  Gets the top artists by scrobble count for the given number of days.
  Returns a list of maps with artist information and play counts.
  """
  def get_top_artists_by_days(days, opts) do
    limit = Keyword.get(opts, :limit, 10)
    current_time = Keyword.get_lazy(opts, :current_time, &DateTime.utc_now/0)
    timezone = Keyword.get(opts, :timezone, &resolve_timezone!/0)

    cutoff_timestamp =
      current_time
      |> DateTime.add(-days, :day)
      |> NaiveDateTime.beginning_of_day()
      |> DateTime.from_naive!(timezone)
      |> DateTime.to_unix()

    query =
      from t in Track,
        where: t.scrobbled_at_uts >= ^cutoff_timestamp,
        group_by: [
          fragment("json_extract(artist, '$.name')"),
          fragment("json_extract(artist, '$.musicbrainz_id')")
        ],
        select: %{
          artist_name: fragment("json_extract(artist, '$.name')"),
          artist_musicbrainz_id: fragment("json_extract(artist, '$.musicbrainz_id')"),
          play_count: count(t.scrobbled_at_uts)
        },
        order_by: [desc: count(t.scrobbled_at_uts)],
        limit: ^limit

    Repo.all(query)
  end

  @doc """
  Gets top albums for multiple time periods (30, 90, 365 days).
  Returns a map with the results for each period, along with collected and
  wishlisted releases.
  """
  def get_top_albums_by_periods(opts) do
    last_30_days = get_top_albums_by_days(30, opts)
    last_90_days = get_top_albums_by_days(90, opts)
    last_365_days = get_top_albums_by_days(365, opts)

    all_album_ids =
      (last_30_days ++ last_90_days ++ last_365_days)
      |> Enum.map(fn t -> t.album_musicbrainz_id end)
      |> Enum.uniq()
      |> Enum.reject(fn musicbrainz_id -> musicbrainz_id == "" end)

    collected_releases = Collection.collected_releases(all_album_ids)
    wishlisted_releases = Wishlist.wishlisted_releases(all_album_ids)

    %{
      collected_releases: collected_releases,
      wishlisted_releases: wishlisted_releases,
      last_30_days: last_30_days,
      last_90_days: last_90_days,
      last_365_days: last_365_days
    }
  end

  @doc """
  Gets top artists for multiple time periods (30, 90, 365 days).
  Returns a map with the results for each period.
  """
  def get_top_artists_by_periods(opts) do
    last_30_days = get_top_artists_by_days(30, opts)
    last_90_days = get_top_artists_by_days(90, opts)
    last_365_days = get_top_artists_by_days(365, opts)

    %{
      last_30_days: last_30_days,
      last_90_days: last_90_days,
      last_365_days: last_365_days
    }
  end

  defp resolve_timezone! do
    Application.get_env(:music_library, MusicLibraryWeb)
    |> Keyword.fetch!(:timezone)
  end
end
