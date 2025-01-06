defmodule MusicLibrary.WishlistTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Wishlist
  import MusicLibrary.RecordsFixtures

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

    test "it respects limit" do
      assert [%{title: "Brave"}] = Wishlist.search_records("brave", limit: 1)
    end

    test "it respects offset" do
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

  describe "count/0" do
    setup [:fill_wishlist]

    test "returns the count of records in the wishlist, excluding purchased records" do
      assert 3 = Wishlist.count()
    end
  end
end
