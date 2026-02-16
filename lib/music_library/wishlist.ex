defmodule MusicLibrary.Wishlist do
  import Ecto.Query, warn: false

  alias MusicLibrary.Records
  alias MusicLibrary.Records.{RecordRelease, SearchIndex}
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

  def wishlisted_releases_query do
    from rr in RecordRelease,
      where: is_nil(rr.purchased_at),
      select: %{record_id: rr.record_id, cover_hash: rr.cover_hash, release_id: rr.release_id}
  end

  defp base_search do
    from r in SearchIndex,
      where: is_nil(r.purchased_at)
  end
end
