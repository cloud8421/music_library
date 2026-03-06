defmodule MusicLibrary.Search do
  @moduledoc """
  Universal search functionality across Records and Artists.

  This module provides unified search across:
  - Records in Collection (purchased records)
  - Records in Wishlist (unpurchased records)
  - Artists
  """

  import Ecto.Query, warn: false

  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibrary.{Collection, RecordSets, Repo, Wishlist}
  alias MusicLibrary.Records.ArtistRecord

  @pagination Application.compile_env!(:music_library, :pagination)

  @type search_opts :: [limit: non_neg_integer()]

  @doc """
  Performs a universal search across all entity types.

  Returns a map with grouped results:
  - :collection - Records in the collection
  - :wishlist - Records in the wishlist
  - :artists - Artists
  """
  @spec universal_search(String.t(), search_opts()) :: map()
  def universal_search(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, @pagination[:search_preview_limit])

    %{
      collection: search_collection(query, limit),
      wishlist: search_wishlist(query, limit),
      artists: search_artists(query, limit),
      record_sets: search_record_sets(query, limit)
    }
  end

  @doc """
  Searches records in the collection (purchased records).
  """
  @spec search_collection(String.t(), non_neg_integer()) :: [map()]
  def search_collection(query, limit \\ @pagination[:search_preview_limit]) do
    Collection.search_records(query, limit: limit)
  end

  @doc """
  Searches records in the wishlist (unpurchased records).
  """
  @spec search_wishlist(String.t(), non_neg_integer()) :: [map()]
  def search_wishlist(query, limit \\ @pagination[:search_preview_limit]) do
    Wishlist.search_records(query, limit: limit)
  end

  @doc """
  Searches artists by name.

  Searches across artist names in the artist_records table,
  returning distinct artists that match the query.
  """
  @spec search_artists(String.t(), non_neg_integer()) :: [map()]
  def search_artists(query, limit \\ @pagination[:search_preview_limit]) do
    case String.trim(query) do
      "" ->
        []

      trimmed_query ->
        normalized_query = String.downcase(trimmed_query)

        q =
          from ar in ArtistRecord,
            join: ai in ArtistInfo,
            on: ar.musicbrainz_id == ai.id,
            where:
              fragment("lower(unaccent(artist ->> '$.name')) LIKE ?", ^"%#{normalized_query}%"),
            group_by: ar.musicbrainz_id,
            select: %{artist: ar.artist, image_data_hash: ai.image_data_hash},
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
  @spec search_counts(String.t()) :: map()
  def search_counts(query) do
    %{
      collection_count: Collection.search_records_count(query),
      wishlist_count: Wishlist.search_records_count(query),
      artists_count: search_artists_count(query),
      record_sets_count: RecordSets.count_record_sets(query)
    }
  end

  @doc """
  Searches record sets by name, description, and contained records.
  """
  @spec search_record_sets(String.t(), non_neg_integer()) :: [map()]
  def search_record_sets(query, limit \\ @pagination[:search_preview_limit]) do
    RecordSets.search_record_sets(query, limit: limit)
  end

  @doc """
  Gets the count of artists matching the search query.
  """
  @spec search_artists_count(String.t()) :: non_neg_integer()
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
