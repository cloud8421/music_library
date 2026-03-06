defmodule MusicLibrary.ScrobbleActivity do
  import Ecto.Query

  alias LastFm.{Scrobble, Track}
  alias MusicBrainz.Release
  alias MusicLibrary.{Collection, Records.ArtistRecord, Repo, Secrets, Wishlist}

  @pagination Application.compile_env!(:music_library, :pagination)

  @spec can_scrobble?() :: boolean()
  def can_scrobble? do
    Secrets.get("last_fm_session_key") !== nil
  end

  @spec scrobble_release(map(), keyword()) :: {:ok, term()} | {:error, term()}
  def scrobble_release(release_with_tracks, opts) when is_list(opts) do
    case Enum.sort(opts) do
      [finished_at: _, started_at: _] ->
        raise ArgumentError, """
        Cannot scrobble a release with both started_at and finished_at.
          Remove either of them.
        """

      [started_at: started_at] ->
        scrobble_release(release_with_tracks, {:started_at, started_at})

      [finished_at: finished_at] ->
        scrobble_release(release_with_tracks, {:finished_at, finished_at})
    end
  end

  @spec scrobble_release(map(), {:finished_at, DateTime.t()}) :: {:ok, term()} | {:error, term()}
  def scrobble_release(release_with_tracks, {:finished_at, finished_at}) do
    release_duration = Release.release_duration(release_with_tracks)
    started_at = DateTime.add(finished_at, -release_duration, :millisecond)
    scrobble_release(release_with_tracks, {:started_at, started_at})
  end

  @spec scrobble_release(map(), {:started_at, DateTime.t()}) :: {:ok, term()} | {:error, term()}
  def scrobble_release(release_with_tracks, {:started_at, started_at}) do
    release_duration = Release.release_duration(release_with_tracks)

    if release_duration == 0 do
      {:error, :no_duration}
    else
      with {:ok, session_key} <- fetch_session_key() do
        {scrobbles, _finished_at} =
          release_with_tracks
          |> MusicBrainz.Release.tracks()
          |> to_scrobbles(release_with_tracks, started_at)

        LastFm.scrobble(scrobbles, session_key)
      end
    end
  end

  @spec scrobble_medium(integer(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def scrobble_medium(number, release_with_tracks, opts) when is_list(opts) do
    case Enum.sort(opts) do
      [finished_at: _, started_at: _] ->
        raise ArgumentError, """
        Cannot scrobble a medium with both started_at and finished_at.
          Remove either of them.
        """

      [started_at: started_at] ->
        scrobble_medium(number, release_with_tracks, {:started_at, started_at})

      [finished_at: finished_at] ->
        scrobble_medium(number, release_with_tracks, {:finished_at, finished_at})
    end
  end

  @spec scrobble_medium(integer(), map(), {:finished_at, DateTime.t()}) ::
          {:ok, term()} | {:error, term()}
  def scrobble_medium(number, release_with_tracks, {:finished_at, finished_at}) do
    case find_medium(release_with_tracks, number) do
      {:ok, medium} ->
        medium_duration = Release.medium_duration(medium)
        started_at = DateTime.add(finished_at, -medium_duration, :millisecond)
        scrobble_medium(number, release_with_tracks, {:started_at, started_at})

      {:error, :medium_not_found} ->
        {:error, :medium_not_found}
    end
  end

  @spec scrobble_medium(integer(), map(), {:started_at, DateTime.t()}) ::
          {:ok, term()} | {:error, term()}
  def scrobble_medium(number, release_with_tracks, {:started_at, started_at}) do
    case find_medium(release_with_tracks, number) do
      {:ok, medium} ->
        medium_duration = Release.medium_duration(medium)

        if medium_duration == 0 do
          {:error, :no_duration}
        else
          with {:ok, session_key} <- fetch_session_key() do
            {scrobbles, _finished_at} =
              medium.tracks
              |> to_scrobbles(release_with_tracks, started_at)

            LastFm.scrobble(scrobbles, session_key)
          end
        end

      {:error, :medium_not_found} ->
        {:error, :medium_not_found}
    end
  end

  @spec scrobble_tracks(MapSet.t(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def scrobble_tracks(selected_track_ids, release_with_tracks, opts) when is_list(opts) do
    case Enum.sort(opts) do
      [finished_at: _, started_at: _] ->
        raise ArgumentError, """
        Cannot scrobble tracks with both started_at and finished_at.
          Remove either of them.
        """

      [started_at: started_at] ->
        scrobble_tracks(selected_track_ids, release_with_tracks, {:started_at, started_at})

      [finished_at: finished_at] ->
        scrobble_tracks(selected_track_ids, release_with_tracks, {:finished_at, finished_at})
    end
  end

  @spec scrobble_tracks(MapSet.t(), map(), {:finished_at, DateTime.t()}) ::
          {:ok, term()} | {:error, term()}
  def scrobble_tracks(selected_track_ids, release_with_tracks, {:finished_at, finished_at}) do
    all_tracks = Release.tracks(release_with_tracks)

    selected_tracks =
      Enum.filter(all_tracks, fn track -> MapSet.member?(selected_track_ids, track.id) end)

    tracks_duration = Enum.sum_by(selected_tracks, fn track -> track.length || 0 end)
    started_at = DateTime.add(finished_at, -tracks_duration, :millisecond)
    scrobble_tracks(selected_track_ids, release_with_tracks, {:started_at, started_at})
  end

  @spec scrobble_tracks(MapSet.t(), map(), {:started_at, DateTime.t()}) ::
          {:ok, term()} | {:error, term()}
  def scrobble_tracks(selected_track_ids, release_with_tracks, {:started_at, started_at}) do
    all_tracks = Release.tracks(release_with_tracks)

    selected_tracks =
      Enum.filter(all_tracks, fn track -> MapSet.member?(selected_track_ids, track.id) end)

    tracks_duration = Enum.sum_by(selected_tracks, fn track -> track.length || 0 end)

    if tracks_duration == 0 do
      {:error, :no_duration}
    else
      with {:ok, session_key} <- fetch_session_key() do
        {scrobbles, _finished_at} =
          selected_tracks
          |> to_scrobbles(release_with_tracks, started_at)

        LastFm.scrobble(scrobbles, session_key)
      end
    end
  end

  defp fetch_session_key do
    case Secrets.get("last_fm_session_key") do
      %{value: value} -> {:ok, value}
      nil -> {:error, :no_session_key}
    end
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

  defp find_medium(release_with_tracks, number) do
    case Enum.find(release_with_tracks.media, fn medium -> medium.number == number end) do
      nil -> {:error, :medium_not_found}
      medium -> {:ok, medium}
    end
  end

  defp main_artist_name([]), do: nil
  defp main_artist_name([artist | _rest]), do: artist.name

  @spec list_tracks(map()) :: [map()]
  def list_tracks(params \\ %{}) do
    query = Map.get(params, :query, "")
    page = Map.get(params, :page, 1)
    page_size = Map.get(params, :page_size, @pagination[:tracks_page_size])
    order = Map.get(params, :order, :scrobbled_at)

    all_artists_query =
      from ar in ArtistRecord,
        distinct: true

    base_query =
      from t in Track,
        left_join: cr in subquery(Collection.collected_releases_query()),
        on: cr.release_id == fragment("? ->> '$.musicbrainz_id'", t.album),
        left_join: wr in subquery(Wishlist.wishlisted_releases_query()),
        on: wr.release_id == fragment("? ->> '$.musicbrainz_id'", t.album),
        left_join: ar in subquery(all_artists_query),
        on: wr.record_id == ar.record_id or cr.record_id == ar.record_id,
        select: %{
          track: t,
          collected_record_id: cr.record_id,
          wishlisted_record_id: wr.record_id,
          artist_id: ar.musicbrainz_id,
          cover_hash: coalesce(cr.cover_hash, wr.cover_hash)
        }

    search_query =
      if query == "" do
        base_query
      else
        query_term = "%#{String.downcase(query)}%"

        from t in base_query,
          where:
            like(fragment("lower(?)", t.title), ^query_term) or
              like(fragment("lower(json_extract(?, '$.name'))", t.artist), ^query_term) or
              like(fragment("lower(json_extract(?, '$.title'))", t.album), ^query_term)
      end

    ordered_query =
      case order do
        :scrobbled_at ->
          from t in search_query, order_by: [desc: t.scrobbled_at_uts]

        :title ->
          from t in search_query, order_by: [asc: t.title]

        :artist ->
          from t in search_query, order_by: [asc: fragment("json_extract(?, '$.name')", t.artist)]

        :album ->
          from t in search_query, order_by: [asc: fragment("json_extract(?, '$.title')", t.album)]
      end

    offset = (page - 1) * page_size

    from(t in ordered_query, limit: ^page_size, offset: ^offset)
    |> Repo.all()
  end

  @spec count_tracks() :: non_neg_integer()
  def count_tracks do
    Repo.aggregate(Track, :count, :scrobbled_at_uts)
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
    base_query = from(t in Track)

    search_query =
      if query == "" do
        base_query
      else
        query_term = "%#{String.downcase(query)}%"

        from t in base_query,
          where:
            like(fragment("lower(?)", t.title), ^query_term) or
              like(fragment("lower(json_extract(artist, '$.name'))"), ^query_term) or
              like(fragment("lower(json_extract(album, '$.title'))"), ^query_term)
      end

    Repo.aggregate(search_query, :count, :scrobbled_at_uts)
  end

  @spec count_tracks_missing_artist_musicbrainz_id() :: non_neg_integer()
  def count_tracks_missing_artist_musicbrainz_id do
    query =
      from t in Track,
        where:
          fragment("json_extract(?, '$.musicbrainz_id') IS NULL", t.artist) or
            fragment("json_extract(?, '$.musicbrainz_id') = ''", t.artist),
        select: count(t.scrobbled_at_uts)

    Repo.one(query) || 0
  end

  @spec count_tracks_missing_album_musicbrainz_id() :: non_neg_integer()
  def count_tracks_missing_album_musicbrainz_id do
    query =
      from t in Track,
        where:
          fragment("json_extract(?, '$.musicbrainz_id') IS NULL", t.album) or
            fragment("json_extract(?, '$.musicbrainz_id') = ''", t.album),
        select: count(t.scrobbled_at_uts)

    Repo.one(query) || 0
  end

  @doc """
  Gets artists with missing MusicBrainz IDs, grouped by artist name.

  Returns a list of maps with artist name and track count.
  """
  @spec get_artists_missing_musicbrainz_id(keyword()) :: [map()]
  def get_artists_missing_musicbrainz_id(opts \\ []) do
    limit = Keyword.get(opts, :limit)

    query =
      from t in Track,
        where:
          fragment("json_extract(?, '$.musicbrainz_id') IS NULL", t.artist) or
            fragment("json_extract(?, '$.musicbrainz_id') = ''", t.artist),
        select: %{
          artist_name: fragment("json_extract(?, '$.name')", t.artist),
          track_count: count(t.scrobbled_at_uts)
        },
        group_by: fragment("json_extract(?, '$.name')", t.artist),
        order_by: [desc: count(t.scrobbled_at_uts)]

    query =
      if limit do
        from q in query, limit: ^limit
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets albums with missing MusicBrainz IDs, grouped by album title and artist.

  Returns a list of maps with album title, artist name, and track count.
  """
  @spec get_albums_missing_musicbrainz_id(keyword()) :: [map()]
  def get_albums_missing_musicbrainz_id(opts \\ []) do
    limit = Keyword.get(opts, :limit)

    query =
      from t in Track,
        where:
          fragment("json_extract(?, '$.musicbrainz_id') IS NULL", t.album) or
            fragment("json_extract(?, '$.musicbrainz_id') = ''", t.album),
        select: %{
          album_title: fragment("json_extract(?, '$.title')", t.album),
          artist_name: fragment("json_extract(?, '$.name')", t.artist),
          track_count: count(t.scrobbled_at_uts)
        },
        group_by: [
          fragment("json_extract(?, '$.title')", t.album),
          fragment("json_extract(?, '$.name')", t.artist)
        ],
        order_by: [desc: count(t.scrobbled_at_uts)]

    query =
      if limit do
        from q in query, limit: ^limit
      else
        query
      end

    Repo.all(query)
  end
end
