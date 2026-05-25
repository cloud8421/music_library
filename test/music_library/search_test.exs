defmodule MusicLibrary.SearchTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records
  import MusicLibrary.Fixtures.RecordSets

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

    test "returns record sets matching by name" do
      record_set(%{name: "My Jazz Collection"})
      record_set(%{name: "Rock Favorites"})

      results = Search.universal_search("Jazz")
      assert results.record_sets != []
      names = Enum.map(results.record_sets, & &1.name)
      assert Enum.any?(names, &String.contains?(&1, "Jazz"))
    end

    test "returns record sets matching by description" do
      record_set(%{name: "Favorites", description: "All the prog rock classics"})
      record_set(%{name: "Other", description: "Some other set"})

      results = Search.universal_search("prog rock")
      assert results.record_sets != []
      names = Enum.map(results.record_sets, & &1.name)
      assert Enum.any?(names, &(&1 == "Favorites"))
    end

    test "returns record sets matching by contained record title" do
      {set, _records} = record_set_with_records(1, %{name: "Prog", description: "Prog"})
      contained_title = set.items |> List.first() |> Map.get(:record) |> Map.get(:title)

      results = Search.universal_search(contained_title)
      assert results.record_sets != []
    end

    test "returns record sets matching by contained artist name" do
      # Create a record set with a record that has a unique artist
      {_, [record]} = record_set_with_records(1, %{name: "Artist Set", description: "Testing"})
      artist = hd(record.artists)

      results = Search.universal_search(artist.name)
      record_set_ids = Enum.map(results.record_sets, & &1.id)
      assert record_set_ids != []
    end

    test "returns empty record sets for no match" do
      results = Search.universal_search("zzz_nonexistent_record_set_zzz")
      assert results.record_sets == []
    end

    test "returns empty results for no matches" do
      results = Search.universal_search("zzz_nonexistent_zzz")

      assert results.collection == []
      assert results.wishlist == []
      assert results.artists == []
    end

    test "respects limit", %{collected: _collected} do
      results = Search.universal_search("Marillion", limit: 1)

      assert Enum.count_until(results.collection, 2) <= 1
      assert Enum.count_until(results.wishlist, 2) <= 1
      assert Enum.count_until(results.artists, 2) <= 1
      assert Enum.count_until(results.record_sets, 2) <= 1
    end
  end

  describe "search_counts/1" do
    setup [:create_records]

    test "returns counts per category including record sets" do
      {_set, _records} = record_set_with_records(1, %{name: "Marillion Favorites"})

      counts = Search.search_counts("Marillion")

      assert counts.collection_count >= 1
      assert counts.wishlist_count >= 1
      assert counts.artists_count >= 1
      assert counts.record_sets_count >= 1
    end

    test "returns zero counts for no matches" do
      counts = Search.search_counts("zzz_nonexistent_zzz")

      assert counts.collection_count == 0
      assert counts.wishlist_count == 0
      assert counts.artists_count == 0
      assert counts.record_sets_count == 0
    end
  end

  describe "search_record_sets/2" do
    test "returns record sets matching by name" do
      record_set(%{name: "Best of 2020", description: "Top albums of 2020"})

      results = Search.search_record_sets("2020")
      names = Enum.map(results, & &1.name)
      assert "Best of 2020" in names
    end

    test "returns empty for non-matching query" do
      results = Search.search_record_sets("zzz_nonexistent_zzz")
      assert results == []
    end
  end
end
