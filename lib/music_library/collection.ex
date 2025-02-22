defmodule MusicLibrary.Collection do
  import Ecto.Query, warn: false

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
        order_by: [desc: r.purchased_at],
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

    q |> Repo.all()
  end

  def count_records_by_genre do
    q =
      from r in fragment("records, json_each(records.genres)"),
        group_by: r.value,
        order_by: [desc: count(r.value)],
        select: %{genre: r.value, count: count(r.value)}

    q |> Repo.all()
  end

  defp base_search do
    from r in SearchIndex,
      where: not is_nil(r.purchased_at)
  end
end
