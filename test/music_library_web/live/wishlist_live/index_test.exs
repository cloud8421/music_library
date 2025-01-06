defmodule MusicLibraryWeb.WishlistLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.RecordsFixtures

  defp fill_wishlist(_) do
    records = Enum.map(1..5, fn _ -> record(%{purchased_at: nil}) end)
    %{wishlist: records}
  end

  describe "Wishlist" do
    setup [:fill_wishlist]

    test "can purchase a record and move it to the collection", %{
      conn: conn,
      wishlist: wishlist_records
    } do
      record = Enum.random(wishlist_records)

      conn
      |> visit(~p"/wishlist")
      |> click_link("#records-#{record.id} a", "Purchase")
      |> assert_has("p", text: "Record updated successfully")

      purchased_record = MusicLibrary.Records.get_record!(record.id)

      assert purchased_record.purchased_at !== nil
    end
  end
end
