defmodule MusicLibrary.Wishlist do
  import Ecto.Query, warn: false

  alias MusicLibrary.Repo
  alias MusicLibrary.Records.{Record, SearchParser}

  @fields [:id, :type, :artists, :format, :title, :release, :genres, :musicbrainz_id, :cover_hash]

  def search_records(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    search =
      query
      |> build_search()
      |> limit(^limit)
      |> offset(^offset)
      |> select(^@fields)

    Repo.all(search)
  end

  def search_records_count(query) do
    search = build_search(query)

    Repo.aggregate(search, :count)
  end

  def count do
    q =
      from r in Record,
        where: is_nil(r.purchased_at)

    Repo.aggregate(q, :count)
  end

  defp build_search(query) do
    {:ok, parsed_query} = SearchParser.parse(query)

    base_search =
      from r in Record,
        where: is_nil(r.purchased_at),
        order_by: [r.artists[0]["sort_name"], r.title]

    Enum.reduce(parsed_query, base_search, fn
      {:artist, artist}, search ->
        search |> where([r], like(r.artists, ^"%#{artist}%"))

      {:album, album}, search ->
        search |> where([r], like(r.title, ^"%#{album}%"))

      {:mbid, mbid}, search ->
        search |> where([r], r.musicbrainz_id == ^mbid or like(r.artists, ^"%#{mbid}%"))

      {:format, format}, search ->
        search |> where([r], r.format == ^format)

      {:type, type}, search ->
        search |> where([r], r.type == ^type)

      {:query, raw_query}, search ->
        search
        |> where(
          [r],
          like(r.title, ^"%#{raw_query}%") or like(r.artists, ^"%#{raw_query}%")
        )
    end)
  end
end
