defmodule MusicLibraryWeb.WishlistLive.IndexTest do
  use MusicLibraryWeb.ConnCase
  use Oban.Testing, repo: MusicLibrary.BackgroundRepo

  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records.Record
  alias MusicLibrary.Worker.ImportFromMusicbrainzReleaseGroup

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
      |> click_link("#records-#{record.id} a", "Purchased")
      |> assert_has("p", "Record added to the collection")

      purchased_record = MusicLibrary.Records.get_record!(record.id)

      assert purchased_record.purchased_at !== nil
    end
  end

  describe "Adding a new record" do
    test "enqueues one job per cart item with purchased_at: nil for wishlist", %{conn: conn} do
      Req.Test.stub(MusicBrainz.API, fn conn ->
        case conn.path_info do
          [_ws, _version, "release-group"] ->
            Req.Test.json(conn, release_group_search_results())
        end
      end)

      [first, second | _] = Map.get(release_group_search_results(), "release-groups")
      first_id = first["id"]
      second_id = second["id"]

      conn
      |> visit(~p"/wishlist/import")
      |> fill_in("Search for a record", with: "Marillion Marbles")
      |> click_link("#musicbrainz_#{first_id} a", "CD")
      |> click_link("#musicbrainz_#{second_id} a", "Vinyl")
      |> click_button("Import 2 records")
      |> assert_has("p", text: "Importing 2 records in the background...")

      assert_enqueued(
        worker: ImportFromMusicbrainzReleaseGroup,
        args: %{
          "release_group_id" => first_id,
          "format" => "cd",
          "purchased_at" => nil
        }
      )

      assert_enqueued(
        worker: ImportFromMusicbrainzReleaseGroup,
        args: %{
          "release_group_id" => second_id,
          "format" => "vinyl",
          "purchased_at" => nil
        }
      )

      import Ecto.Query, only: [from: 2]
      query = from(r in Record, where: not is_nil(r.purchased_at))
      assert MusicLibrary.Repo.all(query) == []
    end
  end
end
