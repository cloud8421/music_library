defmodule MusicLibraryWeb.WishlistLive.IndexTest do
  use MusicLibraryWeb.ConnCase
  use Oban.Testing, repo: MusicLibrary.BackgroundRepo

  import Ecto.Query, only: [from: 2]
  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records
  alias MusicLibrary.Records.Record
  alias MusicLibrary.Worker.ImportFromMusicbrainzReleaseGroup
  alias Req.Test

  defp fill_wishlist(_) do
    records = Enum.map(1..5, fn _ -> record(%{purchased_at: nil}) end)
    %{wishlist: records}
  end

  describe "PubSub index_changed" do
    test "reloads stream when live_action is :index", %{conn: conn} do
      session = visit(conn, ~p"/wishlist")

      # Create a new wishlist record behind the scenes (simulating completed background import)
      new_record = record(%{purchased_at: nil})

      refute_has(session, "#records-#{new_record.id}")

      Records.broadcast_index_changed()

      assert_has(session, "#records-#{new_record.id}", timeout: 200)
    end

    test "ignores message when live_action is :import (guard clause)", %{conn: conn} do
      session = visit(conn, ~p"/wishlist/import")

      new_record = record(%{purchased_at: nil})

      Records.broadcast_index_changed()

      # The message is a no-op when the grid is behind the import modal.
      refute_has(session, "#records-#{new_record.id}", timeout: 100)
    end
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

      refute is_nil(purchased_record.purchased_at)
    end
  end

  describe "Adding a new record" do
    test "enqueues one job per cart item with purchased_at: nil for wishlist", %{conn: conn} do
      stub_release_group_search()

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

      query = from(r in Record, where: not is_nil(r.purchased_at))
      assert MusicLibrary.Repo.all(query) == []
    end

    test "imports a single cart item synchronously and navigates to wishlist", %{conn: conn} do
      stub_full_import()

      [first | _] = Map.get(release_group_search_results(), "release-groups")
      first_id = first["id"]

      session =
        conn
        |> visit(~p"/wishlist/import")
        |> fill_in("Search for a record", with: "Marillion Marbles")
        |> click_link("#musicbrainz_#{first_id} a", "CD")
        |> click_button("Import 1 record")
        |> refute_path("/wishlist/import", timeout: 2_000)
        |> assert_path("/wishlist/*", timeout: 2_000)

      [record] = MusicLibrary.Repo.all(Record)

      assert record.musicbrainz_id == first_id
      assert record.title == "Marbles"
      assert record.format == :cd
      assert record.purchased_at == nil
      assert_path(session, ~p"/wishlist/#{record}")

      refute_enqueued(worker: ImportFromMusicbrainzReleaseGroup)
    end
  end

  defp stub_release_group_search do
    Test.stub(MusicBrainz.API, fn conn ->
      case conn.path_info do
        [_ws, _version, "release-group"] ->
          Test.json(conn, release_group_search_results())
      end
    end)
  end

  defp stub_full_import do
    [first | _] = Map.get(release_group_search_results(), "release-groups")
    first_id = first["id"]

    release_group = release_group(:marbles)
    release_group_releases = release_group_releases(:marbles)
    cover_data = marbles_cover_data()

    Test.stub(MusicBrainz.API, fn conn ->
      case conn.path_info do
        [_ws, _version, "release-group", ^first_id] ->
          Test.json(conn, release_group)

        [_ws, _version, "release-group"] ->
          Test.json(conn, release_group_search_results())

        [_ws, _version, "release"] ->
          Test.json(conn, release_group_releases)

        [_release_group, ^first_id, "front"] ->
          Plug.Conn.send_resp(conn, 200, cover_data)
      end
    end)
  end
end
