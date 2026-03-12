defmodule MusicLibrary.ListeningStats do
  @moduledoc """
  Read-only listening analytics derived from Last.fm scrobble data.

  Provides scrobble counts, recent activity feeds, and top albums/artists
  by time period. All queries are read-only joins across LastFm.Track,
  Collection, Wishlist, and ArtistInfo.
  """

  import Ecto.Query

  alias LastFm.Track
  alias MusicLibrary.{Artists, Collection, Records.ArtistRecord, Records.Record, Repo, Wishlist}

  @pagination Application.compile_env!(:music_library, :pagination)

  @type period_opts :: [
          period: atom(),
          limit: non_neg_integer(),
          current_time: DateTime.t(),
          timezone: String.t()
        ]

  @spec scrobble_count() :: non_neg_integer()
  def scrobble_count do
    Repo.aggregate(Track, :count, :scrobbled_at_uts)
  end

  @spec recent_activity(String.t(), non_neg_integer()) :: map()
  def recent_activity(timezone, limit \\ 100) do
    # When we get recent tracks, we need to:
    #
    # - Map each track to a record in the collection (if it exists)
    # - Map each track to a record in the wishlist (if it exists)
    # - Map each track to an artist, knowing that sometimes track artists do
    #   not have the necessary information. In that case we can go from
    #   track -> album -> record -> artist

    all_artists_query =
      from ar in ArtistRecord,
        distinct: true

    tracks_query =
      from t in Track,
        left_join: cr in subquery(Collection.collected_releases_query()),
        on: cr.release_id == fragment("? ->> '$.musicbrainz_id'", t.album),
        left_join: wr in subquery(Wishlist.wishlisted_releases_query()),
        on: wr.release_id == fragment("? ->> '$.musicbrainz_id'", t.album),
        left_join: ar in subquery(all_artists_query),
        on: wr.record_id == ar.record_id or cr.record_id == ar.record_id,
        order_by: [desc: t.scrobbled_at_uts],
        limit: ^limit,
        select: %{
          track: t,
          collected_record_id: cr.record_id,
          wishlisted_record_id: wr.record_id,
          artist_id: ar.musicbrainz_id,
          cover_hash: coalesce(cr.cover_hash, wr.cover_hash)
        }

    recent_tracks = Repo.all(tracks_query)

    recent_tracks =
      recent_tracks
      |> Enum.map(fn %{track: track, artist_id: artist_id} = rt ->
        %{rt | track: polyfill_track(track, timezone, artist_id)}
      end)

    recent_albums =
      recent_tracks
      |> Enum.dedup_by(fn %{track: track} -> track.album end)
      |> Enum.map(fn %{track: track} = tr ->
        tr
        |> Map.delete(:track)
        |> Map.put(
          :album,
          %{
            scrobbled_at_uts: track.scrobbled_at_uts,
            scrobbled_at_label: track.scrobbled_at_label,
            metadata: track.album,
            artist: track.artist,
            cover_url: track.cover_url
          }
        )
      end)

    %{
      recent_tracks: recent_tracks,
      recent_albums: recent_albums
    }
  end

  @spec localize_scrobbled_at(integer(), String.t()) :: String.t()
  def localize_scrobbled_at(uts, timezone) do
    ldt =
      uts
      |> DateTime.from_unix!()
      |> DateTime.shift_zone!(timezone)

    Calendar.strftime(ldt, "%d/%m/%Y %X")
  end

  @doc """
  Gets top albums for the specified time periods (7, 30, 90, 365 days) and all
  time. Returns a list of maps with album information and play counts.
  """
  @spec get_top_albums_by_period(period_opts()) :: [map()]
  def get_top_albums_by_period(opts) do
    case Keyword.get(opts, :period, :last_7_days) do
      :all_time -> get_top_albums(opts)
      :last_7_days -> get_top_albums_by_days(7, opts)
      :last_30_days -> get_top_albums_by_days(30, opts)
      :last_90_days -> get_top_albums_by_days(90, opts)
      :last_365_days -> get_top_albums_by_days(365, opts)
    end
  end

  @doc """
  Gets top artists for a time period (7, 30, 90, 365 days) and all time.
  """
  @spec get_top_artists_by_period(period_opts()) :: [map()]
  def get_top_artists_by_period(opts) do
    case Keyword.get(opts, :period, :last_7_days) do
      :all_time -> get_top_artists(opts)
      :last_7_days -> get_top_artists_by_days(7, opts)
      :last_30_days -> get_top_artists_by_days(30, opts)
      :last_90_days -> get_top_artists_by_days(90, opts)
      :last_365_days -> get_top_artists_by_days(365, opts)
    end
  end

  @doc """
  Gets the top albums by scrobble count across all time.
  Returns a list of maps with album information and play counts.
  """
  @spec get_top_albums(period_opts()) :: [map()]
  def get_top_albums(opts) do
    limit = Keyword.get(opts, :limit, @pagination[:top_items_limit])

    top_albums_base_query()
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets the top albums by scrobble count for the given number of days.
  Returns a list of maps with album information and play counts.
  """
  @spec get_top_albums_by_days(pos_integer(), period_opts()) :: [map()]
  def get_top_albums_by_days(days, opts) do
    limit = Keyword.get(opts, :limit, @pagination[:top_items_limit])
    cutoff_timestamp = cutoff_timestamp(days, opts)

    top_albums_base_query()
    |> where([t], t.scrobbled_at_uts >= ^cutoff_timestamp)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets the top artists by scrobble count across all time.
  Returns a list of maps with artist information and play counts.
  """
  @spec get_top_artists(period_opts()) :: [map()]
  def get_top_artists(opts) do
    limit = Keyword.get(opts, :limit, @pagination[:top_items_limit])

    top_artists_base_query()
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets the top artists by scrobble count for the given number of days.
  Returns a list of maps with artist information and play counts.
  """
  @spec get_top_artists_by_days(pos_integer(), period_opts()) :: [map()]
  def get_top_artists_by_days(days, opts) do
    limit = Keyword.get(opts, :limit, @pagination[:top_items_limit])
    cutoff_timestamp = cutoff_timestamp(days, opts)

    top_artists_base_query()
    |> where([t], t.scrobbled_at_uts >= ^cutoff_timestamp)
    |> limit(^limit)
    |> Repo.all()
  end

  # Shared base queries

  defp top_albums_base_query do
    from t in Track,
      left_join: cr in subquery(Collection.collected_releases_query()),
      on: cr.release_id == fragment("? ->> '$.musicbrainz_id'", t.album),
      left_join: wr in subquery(Wishlist.wishlisted_releases_query()),
      on: wr.release_id == fragment("? ->> '$.musicbrainz_id'", t.album),
      where: fragment("json_extract(album, '$.title') != ''"),
      group_by: [
        fragment("json_extract(album, '$.title')"),
        fragment("json_extract(artist, '$.name')")
      ],
      select: %{
        album_title: fragment("json_extract(album, '$.title')"),
        artist_name: fragment("json_extract(artist, '$.name')"),
        artist_musicbrainz_id: fragment("json_extract(artist, '$.musicbrainz_id')"),
        play_count: count(t.scrobbled_at_uts, :distinct),
        cover_url: fragment("max(?)", t.cover_url),
        album_musicbrainz_id: fragment("json_extract(album, '$.musicbrainz_id')"),
        collected_record_id: cr.record_id,
        wishlisted_record_id: wr.record_id,
        cover_hash: coalesce(cr.cover_hash, wr.cover_hash)
      },
      order_by: [desc: count(t.scrobbled_at_uts, :distinct)]
  end

  defp top_artists_base_query do
    from t in Track,
      left_join: ai in Artists.ArtistInfo,
      on: ai.id == fragment("json_extract(?, '$.musicbrainz_id')", t.artist),
      group_by: [
        fragment("json_extract(artist, '$.name')")
      ],
      select: %{
        name: fragment("json_extract(artist, '$.name')"),
        musicbrainz_id: max(fragment("json_extract(artist, '$.musicbrainz_id')")),
        image_hash: max(ai.image_data_hash),
        play_count: count(t.scrobbled_at_uts, :distinct)
      },
      order_by: [desc: count(t.scrobbled_at_uts, :distinct)]
  end

  defp cutoff_timestamp(days, opts) do
    current_time = Keyword.get_lazy(opts, :current_time, &DateTime.utc_now/0)
    timezone = Keyword.get(opts, :timezone, &MusicLibrary.default_timezone/0)

    current_time
    |> DateTime.add(-days, :day)
    |> NaiveDateTime.beginning_of_day()
    |> DateTime.from_naive!(timezone)
    |> DateTime.to_unix()
  end

  defp polyfill_track(track, timezone, artist_id) do
    %{
      track
      | scrobbled_at_label: localize_scrobbled_at(track.scrobbled_at_uts, timezone),
        artist: polyfill_artist(track.artist, artist_id)
    }
  end

  @spec get_last_listened_track(Record.t()) :: Track.t() | nil
  def get_last_listened_track(record) do
    q =
      from t in scrobbles_for_record_query(record),
        order_by: [desc: t.scrobbled_at_uts],
        limit: 1

    Repo.one(q)
  end

  @spec play_count(Record.t()) :: non_neg_integer()
  def play_count(record) do
    record
    |> scrobbles_for_record_query()
    |> Repo.aggregate(:count)
  end

  defp scrobbles_for_record_query(record) do
    record_id = record.id

    q =
      from r in fragment("records, json_each(records.release_ids)"),
        where: fragment("records.id = ?", ^record_id),
        select: r.value

    release_ids = Repo.all(q)
    main_artist_name = Record.main_artist(record).name
    record_title = record.title

    from t in Track,
      where: fragment("? ->> '$.musicbrainz_id'", t.album) in ^release_ids,
      or_where:
        fragment("? ->> '$.title'", t.album) == ^record_title and
          fragment("? ->> '$.name'", t.artist) == ^main_artist_name
  end

  defp polyfill_artist(artist, musicbrainz_id) do
    if is_nil(artist.musicbrainz_id) or artist.musicbrainz_id == "" do
      %{artist | musicbrainz_id: musicbrainz_id}
    else
      artist
    end
  end
end
