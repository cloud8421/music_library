defmodule MusicLibrary.Collection do
  import Ecto.Query, warn: false
  import MusicLibrary.Records, only: [order_alphabetically: 0]

  alias MusicLibrary.Records
  alias MusicLibrary.Records.{Record, SearchIndex}
  alias MusicLibrary.Repo

  def search_records(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    order = Keyword.get(opts, :order, :alphabetical)

    Records.search_records(base_search(), query, limit: limit, offset: offset, order: order)
  end

  def search_records_count(query) do
    Records.search_records_count(base_search(), query)
  end

  def count_records_by_format do
    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        group_by: r.format,
        order_by: [desc: count(r.id)],
        select: {r.format, count(r.id)}

    Repo.all(q)
  end

  def count_records_by_type do
    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        group_by: r.type,
        order_by: [desc: count(r.id)],
        select: {r.type, count(r.id)}

    Repo.all(q)
  end

  def get_latest_record! do
    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        order_by: [{:desc, r.purchased_at}, order_alphabetically()],
        limit: 1,
        select: ^Records.essential_fields()

    Repo.one!(q)
  end

  def get_random_record! do
    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        order_by: fragment("RANDOM()"),
        limit: 1,
        select: ^Records.essential_fields()

    Repo.one!(q)
  end

  def collected_releases(release_ids) do
    q =
      from r in fragment("records, json_each(records.release_ids)"),
        where: r.value in ^release_ids,
        where: fragment("records.purchased_at IS NOT NULL"),
        select: %{record_id: fragment("records.id"), release_id: r.value}

    Repo.all(q)
  end

  def count_records_by_artist(opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)

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

  def count_records_by_genre(opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)

    q =
      from r in fragment("records, json_each(records.genres)"),
        where: fragment("records.purchased_at IS NOT NULL"),
        group_by: r.value,
        order_by: [desc: fragment("count(1)")],
        select: {r.value, fragment("count(1)")},
        limit: ^limit

    Repo.all(q)
  end

  defp base_search do
    from r in SearchIndex,
      where: not is_nil(r.purchased_at)
  end
end
