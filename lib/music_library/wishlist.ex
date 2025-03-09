defmodule MusicLibrary.Wishlist do
  import Ecto.Query, warn: false

  alias MusicLibrary.Records
  alias MusicLibrary.Records.SearchIndex
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

  def count do
    Repo.aggregate(base_search(), :count)
  end

  def wishlisted_releases(release_ids) do
    q =
      from r in fragment("records, json_each(records.release_ids)"),
        where: r.value in ^release_ids,
        where: fragment("records.purchased_at IS NULL"),
        select: %{record_id: fragment("records.id"), release_id: r.value}

    Repo.all(q)
  end

  defp base_search do
    from r in SearchIndex,
      where: is_nil(r.purchased_at)
  end
end
