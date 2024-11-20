defmodule MusicLibraryWeb.WishlistLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest
  import MusicLibrary.RecordsFixtures

  defp fill_wishlist(_) do
    records = Enum.map(1..5, fn _ -> record_fixture(%{purchased_at: nil}) end)
    %{wishlist: records}
  end

  describe "Wishlist" do
    setup [:fill_wishlist]

    test "can purchase a record and move it to the collection", %{
      conn: conn,
      wishlist: wishlist_records
    } do
      {:ok, index_live, _html} = live(conn, ~p"/wishlist")

      record = Enum.random(wishlist_records)

      index_live
      |> element("#records-#{record.id} a", "Purchase")
      |> render_click() =~ "Record updated successfully"

      purchased_record = MusicLibrary.Records.get_record!(record.id)

      assert purchased_record.purchased_at !== nil
    end
  end
end
