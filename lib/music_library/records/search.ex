defmodule MusicLibrary.Records.Search do
  @moduledoc """
  FTS5 search and genre listing for records.

  Integrates with `SearchParser` to support structured, tagged queries
  (`artist:`, `album:`, `genre:`, `format:`, `type:`, `mbid:`, `purchase_year:`, `release_year:`).
  """

  import Ecto.Query, warn: false
  import MusicLibrary.Records.Query

  alias MusicLibrary.Records.{SearchIndex, SearchParser}
  alias MusicLibrary.Repo

  @spec search_records(Ecto.Queryable.t(), String.t(), MusicLibrary.Types.pagination_opts()) ::
          [SearchIndex.t()]
  def search_records(initial_search, query, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.fetch!(opts, :offset)
    order = Keyword.fetch!(opts, :order)

    search =
      initial_search
      |> build_search(query, order)
      |> limit(^limit)
      |> offset(^offset)
      |> select(^essential_fields())

    Repo.all(search)
  end

  @spec search_records_count(Ecto.Queryable.t(), String.t()) :: non_neg_integer()
  def search_records_count(initial_search, query) do
    search = build_search(initial_search, query)

    Repo.aggregate(search, :count)
  end

  @spec list_genres() :: [String.t()]
  def list_genres do
    q =
      from r in fragment("records, json_each(records.genres)"),
        select: fragment("DISTINCT value"),
        order_by: fragment("value COLLATE NOCASE ASC")

    Repo.all(q)
  end

  defp fts_escape(term) do
    if String.contains?(term, ["'", " ", "\"", "(", ")", "^", "-", ":", "?", ".", "&"]) do
      escaped = String.replace(term, "\"", "\"\"")
      "\"#{escaped}\"*"
    else
      "#{term}*"
    end
  end

  defp fts_query_escape(query) do
    query
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map_join(" AND ", &fts_escape/1)
  end

  defp build_search(initial_search, query, order \\ :alphabetical) do
    {:ok, parsed_query} =
      SearchParser.parse(query)

    search_with_order =
      case order do
        :alphabetical ->
          initial_search
          |> order_by(order_alphabetically())

        :purchase ->
          initial_search
          |> order_by([r], [
            {:desc, r.purchased_at},
            order_alphabetically()
          ])

        :insertion ->
          initial_search
          |> order_by([r], [
            {:desc, r.inserted_at},
            order_alphabetically()
          ])

        :release ->
          initial_search
          |> order_by([r], [
            {:desc, r.release_date},
            order_alphabetically()
          ])
      end

    Enum.reduce(parsed_query, search_with_order, fn
      {:artist, artist}, search ->
        escaped_artist = fts_escape(artist)

        search
        |> where(
          fragment(
            "records_search_index MATCH '{artists normalized_artists} : ' || ?",
            ^escaped_artist
          )
        )

      {:album, album}, search ->
        escaped_album = fts_escape(album)

        search
        |> where(
          fragment(
            "records_search_index MATCH '{title normalized_title} : ' || ?",
            ^escaped_album
          )
        )

      {:genre, genre}, search ->
        escaped_genre = fts_escape(genre)

        search
        |> where(fragment("records_search_index MATCH 'genres : ' || ?", ^escaped_genre))

      {:mbid, mbid}, search ->
        escaped_mbid = fts_escape(mbid)

        search
        |> where(fragment("records_search_index MATCH ?", ^escaped_mbid))

      {:format, format}, search ->
        search |> where([r], r.format == ^format)

      {:type, type}, search ->
        search |> where([r], r.type == ^type)

      {:purchase_year, year}, search ->
        search
        |> where(
          [r],
          fragment(
            "? >= ? and ? < ?",
            r.purchased_at,
            ^to_string(year),
            r.purchased_at,
            ^to_string(year + 1)
          )
        )

      {:release_year, year}, search ->
        search
        |> where([r], fragment("substr(?, 1, 4) = ?", r.release_date, ^to_string(year)))

      {:query, ""}, search ->
        search

      {:query, raw_query}, search ->
        escaped_query = fts_query_escape(raw_query)

        search
        |> where(fragment("records_search_index MATCH ?", ^escaped_query))
    end)
  end
end
