defmodule MusicLibrary.ListeningStats do
  @moduledoc """
  Listening analytics and track management derived from Last.fm scrobble data.

  Provides scrobble counts, recent activity feeds, top albums/artists
  by time period, and track CRUD/search/listing. Cross-references tracks
  with records (via `record_releases`), artists (via `artist_records`),
  and `Artists.ArtistInfo`.
  """

  import Ecto.Query

  alias LastFm.Track

  alias MusicLibrary.{
    Artists,
    BackgroundRepo,
    Records.Record,
    Repo,
    Worker
  }

  @pagination Application.compile_env!(:music_library, :pagination)

  @insertable_fields [
    :musicbrainz_id,
    :title,
    :artist,
    :album,
    :cover_url,
    :scrobbled_at_uts,
    :scrobbled_at_label,
    :last_fm_data
  ]

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

  @spec update([LastFm.Track.t()]) :: {:ok, non_neg_integer()} | no_return
  def update(tracks) do
    track_params =
      tracks
      |> Enum.map(fn t -> Map.take(t, @insertable_fields) end)
      |> Enum.map(&Map.to_list/1)

    {count, tracks} =
      Repo.insert_all(Track, track_params,
        on_conflict: :nothing,
        conflict_target: [:scrobbled_at_uts, :title],
        returning: true
      )

    tracks
    |> MusicLibrary.ScrobbleRules.apply_all_rules()
    |> MusicLibrary.ScrobbleRules.log_apply_results()

    Phoenix.PubSub.broadcast(MusicLibrary.PubSub, "listening_stats:update", %{track_count: count})

    {:ok, count}
  end

  @spec subscribe() :: :ok
  def subscribe do
    Phoenix.PubSub.subscribe(MusicLibrary.PubSub, "listening_stats:update")
  end

  @spec refresh() :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def refresh do
    Worker.RefreshScrobbles.new(%{})
    |> Oban.insert()
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

  @spec artist_play_count(String.t()) :: non_neg_integer()
  def artist_play_count(artist_musicbrainz_id) do
    from(t in Track,
      where: fragment("json_extract(?, '$.musicbrainz_id')", t.artist) == ^artist_musicbrainz_id,
      select: count(t.scrobbled_at_uts, :distinct)
    )
    |> Repo.one!()
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

    tracks_query =
      from t in tracks_with_record_info_query(),
        order_by: [desc: t.scrobbled_at_uts],
        limit: ^limit

    recent_tracks = Repo.all(tracks_query)

    recent_tracks =
      recent_tracks
      |> Enum.map(fn %{track: track, artist_id: artist_id, matching_records: matching_records} =
                       rt ->
        parsed = parse_matching_records(matching_records)

        rt
        |> Map.put(:track, polyfill_track(track, timezone, artist_id))
        |> Map.put(:matching_records, parsed)
        |> derive_legacy_record_ids(parsed)
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

  # Track CRUD + listing

  @spec list_tracks(map()) :: [map()]
  def list_tracks(params \\ %{}) do
    query = Map.get(params, :query, "")
    page = Map.get(params, :page, 1)
    page_size = Map.get(params, :page_size, @pagination[:tracks_page_size])
    order = Map.get(params, :order, :scrobbled_at)

    search_query =
      tracks_with_record_info_query()
      |> search_query(query)

    ordered_query =
      case order do
        :scrobbled_at ->
          from [t] in search_query, order_by: [desc: t.scrobbled_at_uts]

        :title ->
          from [t] in search_query, order_by: [asc: t.title]

        :artist ->
          from [t] in search_query,
            order_by: [asc: fragment("json_extract(?, '$.name')", t.artist)]

        :album ->
          from [t] in search_query,
            order_by: [asc: fragment("json_extract(?, '$.title')", t.album)]
      end

    offset = (page - 1) * page_size

    from(t in ordered_query, limit: ^page_size, offset: ^offset)
    |> Repo.all()
    |> Enum.map(fn result ->
      parsed = parse_matching_records(result.matching_records)

      result
      |> Map.put(:matching_records, parsed)
      |> derive_legacy_record_ids(parsed)
    end)
  end

  @spec get_track!(integer() | String.t()) :: LastFm.Track.t()
  def get_track!(scrobbled_at_uts) when is_integer(scrobbled_at_uts) do
    Repo.get!(Track, scrobbled_at_uts)
  end

  def get_track!(scrobbled_at_uts) when is_binary(scrobbled_at_uts) do
    case Integer.parse(scrobbled_at_uts) do
      {id, ""} -> get_track!(id)
      _ -> raise Ecto.NoResultsError, queryable: Track
    end
  end

  @spec update_track(LastFm.Track.t(), map()) ::
          {:ok, LastFm.Track.t()} | {:error, Ecto.Changeset.t()}
  def update_track(%Track{} = track, attrs) do
    changeset = Track.changeset(track, attrs)
    Repo.update(changeset)
  end

  @spec delete_track(LastFm.Track.t()) :: {:ok, LastFm.Track.t()} | {:error, Ecto.Changeset.t()}
  def delete_track(%Track{} = track) do
    Repo.delete(track)
  end

  @spec search_tracks_count(String.t()) :: non_neg_integer()
  def search_tracks_count(query \\ "") do
    from(t in Track)
    |> search_query(query)
    |> Repo.aggregate(:count, :scrobbled_at_uts)
  end

  # Top albums/artists by period

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

    Track
    |> top_albums_aggregate_query(limit)
    |> top_albums_attach_metadata()
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

    cutoff_timestamp
    |> tracks_since_query()
    |> subquery()
    |> top_albums_aggregate_query(limit)
    |> top_albums_attach_metadata()
    |> Repo.all()
  end

  @doc """
  Gets the top artists by scrobble count across all time.
  Returns a list of maps with artist information and play counts.
  """
  @spec get_top_artists(period_opts()) :: [map()]
  def get_top_artists(opts) do
    limit = Keyword.get(opts, :limit, @pagination[:top_items_limit])

    Track
    |> top_artists_aggregate_query(limit)
    |> top_artists_attach_metadata()
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

    cutoff_timestamp
    |> tracks_since_query()
    |> subquery()
    |> top_artists_aggregate_query(limit)
    |> top_artists_attach_metadata()
    |> Repo.all()
  end

  # Shared base queries

  # Returns all records sharing the same release group as the scrobbled track's
  # album release ID via a `json_group_array` subquery. The join path is:
  # track.album ->> '$.musicbrainz_id' (release ID) -> record_releases.release_id
  # -> records.musicbrainz_id -> all records with that musicbrainz_id.
  # Correlated subqueries scale with the outer LIMIT, not the table size.
  # See issue #148.
  defp tracks_with_record_info_query do
    from t in Track,
      select: %{
        track: t,
        matching_records:
          fragment(
            """
            (SELECT json_group_array(json_object(\
            'id', r.id, \
            'title', r.title, \
            'format', r.format, \
            'type', r.type, \
            'purchased_at', r.purchased_at, \
            'cover_hash', r.cover_hash\
            )) \
            FROM records r \
            JOIN record_releases rr ON rr.record_id = r.id \
            WHERE rr.release_id = (? ->> '$.musicbrainz_id'))\
            """,
            t.album
          ),
        artist_id:
          fragment(
            """
            (SELECT min(ar.musicbrainz_id) FROM artist_records ar \
            WHERE ar.record_id = (\
            SELECT rr.record_id FROM record_releases rr \
            WHERE rr.release_id = (? ->> '$.musicbrainz_id') \
            LIMIT 1\
            ))\
            """,
            t.album
          ),
        cover_hash:
          fragment(
            """
            (SELECT r.cover_hash FROM records r \
            JOIN record_releases rr ON rr.record_id = r.id \
            WHERE rr.release_id = (? ->> '$.musicbrainz_id') \
            AND r.purchased_at IS NOT NULL \
            ORDER BY r.id \
            LIMIT 1)\
            """,
            t.album
          )
      }
  end

  # Wraps a date-filtered scan with `limit: -1` so SQLite cannot flatten the
  # subquery into the outer GROUP BY. The forced materialization lets the
  # optimizer use `scrobbled_tracks_scrobbled_at_uts_title_index` for the
  # range scan instead of falling through to the album/artist composite index.
  # See issue #148.
  defp tracks_since_query(cutoff_timestamp) do
    from t in Track,
      where: t.scrobbled_at_uts >= ^cutoff_timestamp,
      limit: -1,
      select: %{
        scrobbled_at_uts: t.scrobbled_at_uts,
        album: t.album,
        artist: t.artist,
        cover_url: t.cover_url
      }
  end

  # Uses `json_extract(?, '$.path')` rather than the equivalent `? ->> '$.path'`
  # because the existing composite index `scrobbled_tracks_album_title_artist_name_index`
  # is built on `json_extract(...)`. SQLite requires the GROUP BY expression
  # to match the index expression exactly to use the index for natural ordering.
  defp top_albums_aggregate_query(track_source, limit) do
    from t in track_source,
      where: fragment("json_extract(?, '$.title')", t.album) != "",
      group_by: [
        fragment("json_extract(?, '$.title')", t.album),
        fragment("json_extract(?, '$.name')", t.artist)
      ],
      select: %{
        album_title: fragment("json_extract(?, '$.title')", t.album),
        artist_name: fragment("json_extract(?, '$.name')", t.artist),
        artist_musicbrainz_id: fragment("json_extract(?, '$.musicbrainz_id')", t.artist),
        play_count: count(t.scrobbled_at_uts, :distinct),
        cover_url: fragment("max(?)", t.cover_url),
        album_musicbrainz_id: fragment("json_extract(?, '$.musicbrainz_id')", t.album)
      },
      order_by: [desc: count(t.scrobbled_at_uts, :distinct)],
      limit: ^limit
  end

  # Attaches `record_releases` and `cover_hash` lookups to the LIMIT'd
  # aggregate result via correlated scalar subqueries. The cost of these
  # lookups scales with the number of result rows (≤ limit), not with the
  # size of `record_releases`.
  defp top_albums_attach_metadata(aggregate_query) do
    from g in subquery(aggregate_query),
      select: %{
        album_title: g.album_title,
        artist_name: g.artist_name,
        artist_musicbrainz_id: g.artist_musicbrainz_id,
        play_count: g.play_count,
        cover_url: g.cover_url,
        album_musicbrainz_id: g.album_musicbrainz_id,
        collected_record_id:
          fragment(
            "(SELECT min(record_id) FROM record_releases WHERE release_id = ? AND purchased_at IS NOT NULL)",
            g.album_musicbrainz_id
          ),
        wishlisted_record_id:
          fragment(
            "(SELECT min(record_id) FROM record_releases WHERE release_id = ? AND purchased_at IS NULL)",
            g.album_musicbrainz_id
          ),
        cover_hash:
          fragment(
            "coalesce((SELECT min(cover_hash) FROM record_releases WHERE release_id = ? AND purchased_at IS NOT NULL), (SELECT min(cover_hash) FROM record_releases WHERE release_id = ? AND purchased_at IS NULL))",
            g.album_musicbrainz_id,
            g.album_musicbrainz_id
          )
      }
  end

  # See note on `top_albums_aggregate_query/2` about `json_extract` vs `->>`.
  # The same applies for `scrobbled_tracks_artist_name_index`.
  defp top_artists_aggregate_query(track_source, limit) do
    from t in track_source,
      group_by: fragment("json_extract(?, '$.name')", t.artist),
      select: %{
        name: fragment("json_extract(?, '$.name')", t.artist),
        musicbrainz_id: max(fragment("json_extract(?, '$.musicbrainz_id')", t.artist)),
        play_count: count(t.scrobbled_at_uts, :distinct)
      },
      order_by: [desc: count(t.scrobbled_at_uts, :distinct)],
      limit: ^limit
  end

  defp top_artists_attach_metadata(aggregate_query) do
    from g in subquery(aggregate_query),
      left_join: ai in Artists.ArtistInfo,
      on: ai.id == g.musicbrainz_id,
      select: %{
        name: g.name,
        musicbrainz_id: g.musicbrainz_id,
        image_hash: ai.image_data_hash,
        play_count: g.play_count
      },
      order_by: [desc: g.play_count]
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

  defp search_query(base_query, ""), do: base_query

  defp search_query(base_query, query) do
    query_term = "%#{String.downcase(query)}%"

    from t in base_query,
      where:
        like(fragment("lower(?)", t.title), ^query_term) or
          like(fragment("lower(json_extract(?, '$.name'))", t.artist), ^query_term) or
          like(fragment("lower(json_extract(?, '$.title'))", t.album), ^query_term)
  end

  defp polyfill_artist(artist, musicbrainz_id) do
    if is_nil(artist.musicbrainz_id) or artist.musicbrainz_id == "" do
      %{artist | musicbrainz_id: musicbrainz_id}
    else
      artist
    end
  end

  defp parse_matching_records(nil), do: []
  defp parse_matching_records("[]"), do: []

  defp parse_matching_records(json) when is_binary(json) do
    json
    |> JSON.decode!()
    |> Enum.map(fn record ->
      %{
        id: record["id"],
        title: record["title"],
        format: record["format"],
        type: record["type"],
        purchased_at: parse_purchased_at(record["purchased_at"]),
        cover_hash: record["cover_hash"]
      }
    end)
  end

  defp parse_purchased_at(nil), do: nil

  defp parse_purchased_at(dt_string) do
    {:ok, dt, _offset} = DateTime.from_iso8601(dt_string)
    dt
  end

  # Temporary bridge: derive collected_record_id and wishlisted_record_id from
  # matching_records so existing LiveView templates keep working until they are
  # migrated to use matching_records directly.
  defp derive_legacy_record_ids(result, matching_records) do
    collected = Enum.find(matching_records, &(&1.purchased_at != nil))
    wishlisted = Enum.find(matching_records, &is_nil(&1.purchased_at))

    result
    |> Map.put(:collected_record_id, collected && collected.id)
    |> Map.put(:wishlisted_record_id, wishlisted && wishlisted.id)
  end
end
