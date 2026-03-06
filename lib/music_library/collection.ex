defmodule MusicLibrary.Collection do
  import Ecto.Query, warn: false
  import MusicLibrary.Records, only: [order_alphabetically: 0]

  alias MusicLibrary.Records
  alias MusicLibrary.Records.{Record, RecordRelease, SearchIndex}
  alias MusicLibrary.Repo

  @excluded_genres Application.compile_env!(:music_library, :excluded_genres)
  @pagination Application.compile_env!(:music_library, :pagination)

  @spec search_records(String.t(), MusicLibrary.Types.pagination_opts()) :: [SearchIndex.t()]
  def search_records(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, @pagination[:default_page_size])
    offset = Keyword.get(opts, :offset, 0)
    order = Keyword.get(opts, :order, :alphabetical)

    Records.search_records(base_search(), query, limit: limit, offset: offset, order: order)
  end

  @spec search_records_count(String.t()) :: non_neg_integer()
  def search_records_count(query) do
    Records.search_records_count(base_search(), query)
  end

  @spec count_records_by_format() :: [{String.t(), non_neg_integer()}]
  def count_records_by_format do
    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        group_by: r.format,
        order_by: [desc: count(r.id)],
        select: {r.format, count(r.id)}

    Repo.all(q)
  end

  @spec count_records_by_type() :: [{String.t(), non_neg_integer()}]
  def count_records_by_type do
    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        group_by: r.type,
        order_by: [desc: count(r.id)],
        select: {r.type, count(r.id)}

    Repo.all(q)
  end

  @spec get_records_on_this_day(Date.t()) :: [SearchIndex.t()]
  def get_records_on_this_day(date \\ Date.utc_today()) do
    month_day = Calendar.strftime(date, "%m-%d")

    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        where: fragment("strftime('%m-%d', ?) = ?", r.release_date, ^month_day),
        order_by: [{:desc, r.release_date}, order_alphabetically()],
        select: ^Records.essential_fields()

    Repo.all(q)
  end

  @spec get_latest_record() :: SearchIndex.t() | nil
  def get_latest_record do
    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        order_by: [{:desc, r.purchased_at}, order_alphabetically()],
        limit: 1,
        select: ^Records.essential_fields()

    Repo.one(q)
  end

  @spec get_latest_record!() :: SearchIndex.t()
  def get_latest_record! do
    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        order_by: [{:desc, r.purchased_at}, order_alphabetically()],
        limit: 1,
        select: ^Records.essential_fields()

    Repo.one!(q)
  end

  @spec get_random_record!() :: SearchIndex.t()
  def get_random_record! do
    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        order_by: fragment("RANDOM()"),
        limit: 1,
        select: ^Records.essential_fields()

    Repo.one!(q)
  end

  @spec count_records_by_artist(keyword()) :: [map()]
  def count_records_by_artist(opts \\ []) do
    limit = Keyword.get(opts, :limit, @pagination[:stats_limit])

    q =
      from r in fragment("records, json_each(records.artists)"),
        where: fragment("records.purchased_at IS NOT NULL"),
        group_by: fragment("? ->> '$.name'", r.value),
        order_by: [desc: fragment("count(1)")],
        select: %{
          id: fragment("? ->> '$.musicbrainz_id'", r.value),
          name: fragment("? ->> '$.name'", r.value),
          count: fragment("count(1)")
        },
        limit: ^limit

    Repo.all(q)
  end

  @spec count_records_by_genre(keyword()) :: [{String.t(), non_neg_integer()}]
  def count_records_by_genre(opts \\ []) do
    limit = Keyword.get(opts, :limit, @pagination[:stats_limit])

    q =
      from r in fragment("records, json_each(records.genres)"),
        where: fragment("records.purchased_at IS NOT NULL"),
        where: r.value not in @excluded_genres,
        group_by: r.value,
        order_by: [desc: fragment("count(1)")],
        select: {r.value, fragment("count(1)")},
        limit: ^limit

    Repo.all(q)
  end

  @spec collected_releases_query() :: Ecto.Query.t()
  def collected_releases_query do
    from rr in RecordRelease,
      where: not is_nil(rr.purchased_at),
      select: %{record_id: rr.record_id, cover_hash: rr.cover_hash, release_id: rr.release_id}
  end

  defp base_search do
    from r in SearchIndex,
      where: not is_nil(r.purchased_at)
  end
end
