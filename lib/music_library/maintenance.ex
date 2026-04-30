defmodule MusicLibrary.Maintenance do
  @moduledoc """
  Context for database maintenance operations, background job monitoring,
  and scrobble data quality diagnostics.
  """

  import Ecto.Query

  alias LastFm.Track
  alias MusicLibrary.BackgroundRepo
  alias MusicLibrary.Repo

  @active_states ~w(available scheduled executing retryable)

  @doc """
  Returns a map of worker module names to their count of active Oban jobs.

  Active jobs are those in "available", "scheduled", "executing", or "retryable" states.
  """
  @spec count_active_jobs_by_worker() :: %{String.t() => non_neg_integer()}
  def count_active_jobs_by_worker do
    q =
      from j in subquery(Oban.Job.query(state: @active_states)),
        group_by: j.worker,
        select: {j.worker, count(j.id)}

    q
    |> BackgroundRepo.all()
    |> Map.new()
  end

  @doc """
  Runs VACUUM on the main database.
  """
  @spec vacuum() :: {:ok, Ecto.Adapters.SQL.query_result()} | {:error, Exception.t()}
  def vacuum do
    Repo.vacuum()
  end

  @doc """
  Runs PRAGMA optimize on the main database.
  """
  @spec optimize() :: {:ok, Ecto.Adapters.SQL.query_result()} | {:error, Exception.t()}
  def optimize do
    Repo.optimize()
  end

  # Scrobble data quality diagnostics

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
