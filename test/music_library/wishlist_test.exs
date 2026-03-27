defmodule MusicLibrary.WishlistTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Wishlist

  defp fill_wishlist(_) do
    records = [
      record(%{purchased_at: nil, title: "Brave"}),
      record(%{purchased_at: nil, title: "Brave"}),
      record(%{purchased_at: nil}),
      record(%{title: "Brave"})
    ]

    %{wishlist: records}
  end

  describe "search_records/2" do
    setup [:fill_wishlist]

    test "returns matching records, excluding purchased records" do
      assert [%{title: "Brave"}, %{title: "Brave"}] = Wishlist.search_records("brave")
    end

    test "respects limit" do
      assert [%{title: "Brave"}] = Wishlist.search_records("brave", limit: 1)
    end

    test "respects offset" do
      [first_match] = Wishlist.search_records("brave", limit: 1)
      [second_match] = Wishlist.search_records("brave", limit: 1, offset: 1)
      assert first_match !== second_match
    end
  end

  describe "search_records_count/1" do
    setup [:fill_wishlist]

    test "returns the count of matching records, excluding purchased records" do
      assert 2 = Wishlist.search_records_count("brave")
    end
  end

  describe "search_records/2 with release_year" do
    test "filters by release year" do
      record(%{purchased_at: nil, title: "Album 1994", release_date: "1994-09-13"})
      record(%{purchased_at: nil, title: "Album 2020", release_date: "2020"})

      assert [%{title: "Album 1994"}] = Wishlist.search_records("release_year:1994")
      assert [%{title: "Album 2020"}] = Wishlist.search_records("release_year:2020")
      assert [] = Wishlist.search_records("release_year:2000")
    end
  end

  describe "count/0" do
    setup [:fill_wishlist]

    test "returns the count of records in the wishlist, excluding purchased records" do
      assert 3 = Wishlist.count()
    end
  end
end
