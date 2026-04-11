defmodule MusicLibrary.Wishlist do
  @moduledoc """
  Queries for wishlisted records (where `purchased_at` is nil).
  """

  import Ecto.Query, warn: false

  alias MusicLibrary.Records
  alias MusicLibrary.Records.SearchIndex
  alias MusicLibrary.Repo

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

  @spec count() :: non_neg_integer()
  def count do
    Repo.aggregate(base_search(), :count)
  end

  defp base_search do
    from r in SearchIndex,
      where: is_nil(r.purchased_at)
  end
end
