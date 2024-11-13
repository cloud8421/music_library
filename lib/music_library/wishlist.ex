defmodule MusicLibrary.Wishlist do
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

  def count do
    Repo.aggregate(base_search(), :count)
  end

  def wishlisted_release_ids(release_ids) do
    q =
      from r in fragment("records, json_each(records.release_ids)"),
        where: r.value in ^release_ids,
        where: fragment("records.purchased_at IS NULL"),
        select: r.value

    Repo.all(q)
  end

  defp base_search do
    from r in Record,
      where: is_nil(r.purchased_at)
  end
end
