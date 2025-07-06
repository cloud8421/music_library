defmodule MusicLibrary.Search do
  @moduledoc """
  Universal search functionality across Records and Artists.

  This module provides unified search across:
  - Records in Collection (purchased records)
  - Records in Wishlist (unpurchased records)
  - Artists
  """

  import Ecto.Query, warn: false

  alias MusicLibrary.Records.ArtistRecord
  alias MusicLibrary.{Collection, Repo, Wishlist}

  @doc """
  Performs a universal search across all entity types.

  Returns a map with grouped results:
  - :collection - Records in the collection
  - :wishlist - Records in the wishlist
  - :artists - Artists

  Options:
  - :limit - Limit per category (default: 5)
  """
  def universal_search(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    %{
      collection: search_collection(query, limit),
      wishlist: search_wishlist(query, limit),
      artists: search_artists(query, limit)
    }
  end

  @doc """
  Searches records in the collection (purchased records).
  """
  def search_collection(query, limit \\ 5) do
    Collection.search_records(query, limit: limit)
  end

  @doc """
  Searches records in the wishlist (unpurchased records).
  """
  def search_wishlist(query, limit \\ 5) do
    Wishlist.search_records(query, limit: limit)
  end

  @doc """
  Searches artists by name.

  Searches across artist names in the artist_records table,
  returning distinct artists that match the query.
  """
  def search_artists(query, limit \\ 5) do
    case String.trim(query) do
      "" ->
        []

      trimmed_query ->
        normalized_query = String.downcase(trimmed_query)

        q =
          from ar in ArtistRecord,
            where:
              fragment("lower(unaccent(artist ->> '$.name')) LIKE ?", ^"%#{normalized_query}%"),
            group_by: ar.musicbrainz_id,
            select: ar.artist,
            limit: ^limit,
            order_by: fragment("artist ->> '$.name'")

        Repo.all(q)
    end
  end

  @doc """
  Gets the count of search results for each category.

  Returns a map with counts for each category:
  - :collection_count
  - :wishlist_count  
  - :artists_count
  """
  def search_counts(query) do
    %{
      collection_count: Collection.search_records_count(query),
      wishlist_count: Wishlist.search_records_count(query),
      artists_count: search_artists_count(query)
    }
  end

  @doc """
  Gets the count of artists matching the search query.
  """
  def search_artists_count(query) do
    case String.trim(query) do
      "" ->
        0

      trimmed_query ->
        normalized_query = String.downcase(trimmed_query)

        # Use a subquery to count distinct musicbrainz_ids
        subquery =
          from ar in ArtistRecord,
            where: fragment("lower(artist ->> '$.name') LIKE ?", ^"%#{normalized_query}%"),
            select: ar.musicbrainz_id,
            distinct: true

        q =
          from s in subquery(subquery),
            select: count()

        Repo.one(q) || 0
    end
  end
end
