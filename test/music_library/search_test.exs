defmodule MusicLibrary.SearchTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Search

  defp create_records(_) do
    collected =
      record_with_artist("Marillion", %{title: "Brave", purchased_at: DateTime.utc_now()})

    wishlisted =
      record_with_artist("Marillion", %{title: "Afraid of Sunlight", purchased_at: nil})

    # Create artist info so search_artists can find artists
    [artist] = collected.artists
    artist_info(artist.musicbrainz_id)

    %{collected: collected, wishlisted: wishlisted}
  end

  describe "universal_search/2" do
    setup [:create_records]

    test "returns collection, wishlist, and artist results", %{
      collected: collected,
      wishlisted: wishlisted
    } do
      results = Search.universal_search("Marillion")

      collection_ids = Enum.map(results.collection, & &1.id)
      assert collected.id in collection_ids

      wishlist_ids = Enum.map(results.wishlist, & &1.id)
      assert wishlisted.id in wishlist_ids

      artist_names = Enum.map(results.artists, fn a -> a.artist.name end)
      assert "Marillion" in artist_names
    end

    test "returns empty results for no matches" do
      results = Search.universal_search("zzz_nonexistent_zzz")

      assert results.collection == []
      assert results.wishlist == []
      assert results.artists == []
    end

    test "respects limit", %{collected: _collected} do
      results = Search.universal_search("Marillion", limit: 1)

      assert length(results.collection) <= 1
      assert length(results.wishlist) <= 1
      assert length(results.artists) <= 1
    end
  end

  describe "search_counts/1" do
    setup [:create_records]

    test "returns counts per category" do
      counts = Search.search_counts("Marillion")

      assert counts.collection_count >= 1
      assert counts.wishlist_count >= 1
      assert counts.artists_count >= 1
    end

    test "returns zero counts for no matches" do
      counts = Search.search_counts("zzz_nonexistent_zzz")

      assert counts.collection_count == 0
      assert counts.wishlist_count == 0
      assert counts.artists_count == 0
    end
  end
end
