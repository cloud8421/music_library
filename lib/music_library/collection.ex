defmodule MusicLibrary.Collection do
  import Ecto.Query, warn: false

  alias MusicLibrary.Repo
  alias MusicLibrary.Records
  alias MusicLibrary.Records.Record

  def search_records(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    Records.search_records(base_search(), query, limit: limit, offset: offset)
  end

  def search_records_count(query) do
    Records.search_records_count(base_search(), query)
  end

  def count_records_by_format do
    q =
      from r in base_search(),
        group_by: r.format,
        order_by: [desc: count(r.id)],
        select: {r.format, count(r.id)}

    Repo.all(q)
  end

  def count_records_by_type do
    q =
      from r in base_search(),
        group_by: r.type,
        order_by: [desc: count(r.id)],
        select: {r.type, count(r.id)}

    Repo.all(q)
  end

  def get_latest_record! do
    q =
      from r in base_search(),
        order_by: [desc: r.purchased_at],
        limit: 1,
        select: ^Records.essential_fields()

    Repo.one!(q)
  end

  defp base_search do
    from r in Record,
      where: not is_nil(r.purchased_at)
  end
end
