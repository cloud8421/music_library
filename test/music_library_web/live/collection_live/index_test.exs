defmodule MusicLibraryWeb.CollectionLive.IndexTest do
  use MusicLibraryWeb.ConnCase
  use Oban.Testing, repo: MusicLibrary.BackgroundRepo

  import MusicBrainz.Fixtures.Release
  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicLibrary.Fixtures.Records
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]
  import Phoenix.LiveViewTest, only: [assert_redirect: 2]

  alias MusicLibrary.Assets
  alias MusicLibrary.Assets.{Image, Transform}
  alias MusicLibrary.Records.Record
  alias MusicLibrary.Worker.ImportFromMusicbrainzReleaseGroup
  alias Phoenix.LiveViewTest
  alias Req.Test

  # make it a multiple of 4 for easier calculations
  @default_records_page_size 4
  @total_records @default_records_page_size + div(@default_records_page_size, 2)

  defp fill_collection(_) do
    records = Enum.map(1..@total_records, fn _ -> record() end)
    %{collection: records}
  end

  describe "Collection" do
    setup [:fill_collection]

    test "shows the chat button", %{conn: conn} do
      conn
      |> visit(~p"/collection")
      |> assert_has("button", "Chat")
    end

    test "auto-opens chat when ?chat=open is present", %{conn: conn} do
      conn
      |> visit(~p"/collection?chat=open")
      |> assert_has("#auto-open-chat")
    end

    test "does not auto-open chat by default", %{conn: conn} do
      conn
      |> visit(~p"/collection")
      |> refute_has("#auto-open-chat")
    end

    test "does not show wishlist records", %{conn: conn} do
      wishlist_records = Enum.map(1..3, fn _ -> record(%{purchased_at: nil}) end)
      session = visit(conn, ~p"/collection")

      for record <- wishlist_records do
        refute_has(session, "#records-#{record.id}")
      end
    end

    test "shows purchased records (first page only)", %{conn: conn} do
      limit = div(@default_records_page_size, 2)
      page_size = div(@default_records_page_size, 4)

      records =
        MusicLibrary.Collection.search_records("", limit: limit)

      {expected_present, expected_absent} =
        Enum.split(records, page_size)

      session =
        conn
        |> visit(~p"/collection?order=alphabetical&page_size=#{page_size}")
        |> click_button("List")

      for record <- expected_present do
        cover_url = cover_url(record, 160)

        session
        |> assert_has("#records-#{record.id}")
        |> assert_has("#records-#{record.id} h2", escape(record.title))
        |> assert_has("#records-#{record.id} p", record.release_date)
        |> assert_has("#records-#{record.id} p", format_label(record.format))
        |> assert_has("#records-#{record.id} p", type_label(record.type))
        |> assert_has("#records-#{record.id} span",
          text: Record.format_as_date(record.purchased_at)
        )
        |> assert_has("img[src='#{cover_url}']")

        for artist <- record.artists do
          assert_has(session, "#records-#{record.id} a", escape(artist.name))
        end
      end

      for record <- expected_absent do
        refute_has(session, "#records-#{record.id}")
      end
    end
  end

  describe "PubSub index_changed" do
    test "reloads stream when live_action is :index", %{conn: conn} do
      {:ok, view, _html} = LiveViewTest.live(conn, ~p"/collection")

      html_before = LiveViewTest.render(view)

      # Create a new record behind the scenes (simulating completed background import)
      _new_record = record()

      # Send the index_changed message directly
      send(view.pid, :records_index_changed)

      # The view should now include the new record
      html_after = LiveViewTest.render(view)
      assert html_after != html_before
    end

    test "ignores message when live_action is :import (guard clause)", %{conn: conn} do
      {:ok, view, _html} = LiveViewTest.live(conn, ~p"/collection/import")

      html_before = LiveViewTest.render(view)

      send(view.pid, :records_index_changed)

      html_after = LiveViewTest.render(view)

      # Should be identical — the message is a no-op when grid is behind modal
      assert html_after == html_before
    end
  end

  describe "Search and pagination" do
    setup [:fill_collection]

    test "uses query string params", %{conn: conn} do
      # We fetch collection records to maintain consistent order
      records = MusicLibrary.Collection.search_records("")
      page_size = div(@default_records_page_size, 4)

      {page_1_records, rest_of_records} = Enum.split(records, page_size)
      {page_2_records, rest_of_records} = Enum.split(rest_of_records, page_size)

      page_2_session =
        visit(conn, ~p"/collection?order=alphabetical&page=2&page_size=#{page_size}")

      for record <- page_1_records do
        refute_has(page_2_session, "#records-#{record.id}")
      end

      for record <- page_2_records do
        assert_has(page_2_session, "#records-#{record.id}")
      end

      for record <- rest_of_records do
        refute_has(page_2_session, "#records-#{record.id}")
      end

      page_2_session
      |> assert_has("#bottom_pagination a", "1")
      |> refute_has("#bottom_pagination a", "2")
      |> assert_has("#bottom_pagination a", "3")

      {page_3_records, rest_of_records} = Enum.split(rest_of_records, page_size)

      # Safeguard - make sure we're not testing against empty lists
      refute Enum.empty?(page_3_records)
      refute Enum.empty?(rest_of_records)

      page_3_session =
        visit(conn, ~p"/collection?order=alphabetical&page=3&page_size=#{page_size}")

      for record <- page_3_records do
        assert_has(page_3_session, "#records-#{record.id}")
      end

      for record <- rest_of_records do
        refute_has(page_3_session, "#records-#{record.id}")
      end

      page_3_session
      |> assert_has("#bottom_pagination a", "1")
      |> assert_has("#bottom_pagination a", "2")
      |> refute_has("#bottom_pagination a", "3")
    end
  end

  describe "Tagged search" do
    setup [:fill_collection]

    test "supports raw queries", %{conn: conn, collection: records} do
      [record | _rest] = records
      qs = [query: record.title]

      session =
        conn
        |> visit(~p"/collection?#{qs}")
        |> click_button("List")

      cover_url = cover_url(record, 160)

      session
      |> assert_has("#records-#{record.id}")
      |> assert_has("#records-#{record.id} h2", escape(record.title))
      |> assert_has("#records-#{record.id} p", record.release_date)
      |> assert_has("#records-#{record.id} p", format_label(record.format))
      |> assert_has("#records-#{record.id} p", type_label(record.type))
      |> assert_has("#records-#{record.id} span",
        text: Record.format_as_date(record.purchased_at)
      )
      |> assert_has("img[src='#{cover_url}']")

      for artist <- record.artists do
        assert_has(session, "#records-#{record.id} a", escape(artist.name))
      end
    end

    test "supports filters", %{conn: conn, collection: records} do
      {artist_with_most_records, records_count} =
        records
        |> Enum.frequencies_by(fn r ->
          [artist] = r.artists
          artist.name
        end)
        |> Enum.max_by(fn {_artist, count} -> count end)

      {present, absent} =
        Enum.split_with(records, fn r ->
          [artist] = r.artists
          artist.name == artist_with_most_records
        end)

      qs = [
        query: ~s(artist:"#{artist_with_most_records}"),
        # Sometimes we generate more reconrds than the default page size, so we
        # need to make sure all of them are included in the results
        page_size: max(@default_records_page_size, records_count)
      ]

      session =
        conn
        |> visit(~p"/collection?#{qs}")
        |> click_button("List")

      for record <- present do
        cover_url = cover_url(record, 160)

        session
        |> assert_has("#records-#{record.id}")
        |> assert_has("#records-#{record.id} h2", escape(record.title))
        |> assert_has("#records-#{record.id} p", record.release_date)
        |> assert_has("#records-#{record.id} p", format_label(record.format))
        |> assert_has("#records-#{record.id} p", type_label(record.type))
        |> assert_has("#records-#{record.id} span",
          text: Record.format_as_date(record.purchased_at)
        )
        |> assert_has("img[src='#{cover_url}']")

        for artist <- record.artists do
          assert_has(session, "#records-#{record.id} a", escape(artist.name))
        end
      end

      for record <- absent do
        refute_has(session, "#records-#{record.id}")
      end
    end
  end

  describe "Updating record metadata" do
    test "can navigate to the record edit form", %{conn: conn} do
      record = record()

      conn
      |> visit(~p"/collection")
      |> click_link("#records-#{record.id} a", "Edit")
      |> assert_has("h2", escape(record.title))
      |> assert_path(~p"/collection/#{record}/edit")
    end

    test "can change the record cover", %{conn: conn} do
      record = record()
      cover_url = cover_url(record, nil)

      session =
        conn
        |> visit(~p"/collection/#{record.id}/edit")
        |> assert_has("img[src='#{cover_url}']")

      session =
        session
        |> upload("Cover art", raven_cover_fixture())
        |> click_button("Save")
        |> assert_has("p", "Record updated successfully")

      updated_record = MusicLibrary.Records.get_record!(record.id)
      updated_cover_url = cover_url(updated_record, 460)

      assert updated_record.cover_hash !== record.cover_hash
      assert_has(session, "img[src='#{updated_cover_url}']")
    end
  end

  describe "Adding a new record" do
    test "shows the import modal", %{conn: conn} do
      conn
      |> visit(~p"/collection")
      |> click_link("Add")
      |> assert_has("label", "Search for a record")
      |> assert_has("div", "No results")
      |> assert_path(~p"/collection/import")
    end

    test "pre-fills the search query from import_query param", %{conn: conn} do
      Test.stub(MusicBrainz.API, fn conn ->
        Test.json(conn, %{"release-groups" => [], "count" => 0})
      end)

      conn
      |> visit(~p"/collection/import?#{[import_query: "test query"]}")
      |> assert_has("input[value='test query']")
    end

    test "adds a record to the cart instead of importing immediately", %{conn: conn} do
      stub_release_group_search()

      [first | _] = Map.get(release_group_search_results(), "release-groups")
      first_id = first["id"]

      conn
      |> visit(~p"/collection/import")
      |> fill_in("Search for a record", with: "Marillion Marbles")
      |> click_link("#musicbrainz_#{first_id} a", "CD")
      |> assert_has("#musicbrainz_#{first_id} span", text: "In cart")
      |> assert_has("#cart-items li", count: 1)
      |> click_link("#musicbrainz_#{first_id} a", "Vinyl")
      |> assert_has("#musicbrainz_#{first_id} span", text: "2 In cart")

      assert MusicLibrary.Repo.all(Record) == []
      refute_enqueued(worker: ImportFromMusicbrainzReleaseGroup)
    end

    test "deduplicates the same {release_group, format} pair", %{conn: conn} do
      stub_release_group_search()

      [first | _] = Map.get(release_group_search_results(), "release-groups")
      first_id = first["id"]

      session =
        conn
        |> visit(~p"/collection/import")
        |> fill_in("Search for a record", with: "Marillion Marbles")
        |> click_link("#musicbrainz_#{first_id} a", "CD")
        |> click_link("#musicbrainz_#{first_id} a", "CD")

      assert_has(session, "#cart-items li", count: 1)
    end

    test "allows same release group with different formats", %{conn: conn} do
      stub_release_group_search()

      [first | _] = Map.get(release_group_search_results(), "release-groups")
      first_id = first["id"]

      session =
        conn
        |> visit(~p"/collection/import")
        |> fill_in("Search for a record", with: "Marillion Marbles")
        |> click_link("#musicbrainz_#{first_id} a", "CD")
        |> click_link("#musicbrainz_#{first_id} a", "Vinyl")

      assert_has(session, "#cart-items li", count: 2)
    end

    test "removes an item from the cart", %{conn: conn} do
      stub_release_group_search()

      [first | _] = Map.get(release_group_search_results(), "release-groups")
      first_id = first["id"]

      session =
        conn
        |> visit(~p"/collection/import")
        |> fill_in("Search for a record", with: "Marillion Marbles")
        |> click_link("#musicbrainz_#{first_id} a", "CD")
        |> click_button("#cart-items button", "Remove")

      assert_has(session, "#cart-empty")
    end

    test "changes the format of a cart item", %{conn: conn} do
      alias Phoenix.LiveViewTest, as: LVT

      stub_release_group_search()

      [first | _] = Map.get(release_group_search_results(), "release-groups")
      first_id = first["id"]

      {:ok, view, _html} = LVT.live(conn, ~p"/collection/import")

      view
      |> LVT.form("#import_form", %{"mb_query" => "Marillion Marbles"})
      |> LVT.render_change()

      view
      |> LVT.element("#musicbrainz_#{first_id} a", "CD")
      |> LVT.render_click()

      view
      |> LVT.element("#cart-items form")
      |> LVT.render_change(%{"format" => "vinyl"})

      assert LVT.render(view) =~ "In cart"
    end

    test "rejects change_format when the resulting pair is already in the cart", %{conn: conn} do
      alias Phoenix.LiveViewTest, as: LVT

      stub_release_group_search()

      [first | _] = Map.get(release_group_search_results(), "release-groups")
      first_id = first["id"]

      {:ok, view, _html} = LVT.live(conn, ~p"/collection/import")

      view
      |> LVT.form("#import_form", %{"mb_query" => "Marillion Marbles"})
      |> LVT.render_change()

      view
      |> LVT.element("#musicbrainz_#{first_id} a", "CD")
      |> LVT.render_click()

      view
      |> LVT.element("#musicbrainz_#{first_id} a", "Vinyl")
      |> LVT.render_click()

      html = LVT.render(view)
      cart_item_ids = Regex.scan(~r/id="cart-item-(\d+)"/, html, capture: :all_but_first)
      assert length(cart_item_ids) == 2

      [first_id_match | _] = cart_item_ids
      [item_id] = first_id_match

      view
      |> LVT.element("#cart-item-#{item_id} form")
      |> LVT.render_change(%{"cart_item_id" => item_id, "format" => "vinyl"})

      html_after = LVT.render(view)
      assert Regex.scan(~r/id="cart-item-/, html_after) |> length() == 2
    end

    test "clears the cart", %{conn: conn} do
      stub_release_group_search()

      [first | _] = Map.get(release_group_search_results(), "release-groups")
      first_id = first["id"]

      conn
      |> visit(~p"/collection/import")
      |> fill_in("Search for a record", with: "Marillion Marbles")
      |> click_link("#musicbrainz_#{first_id} a", "CD")
      |> click_button("Clear all")
      |> assert_has("#cart-empty")
    end

    test "imports a single cart item synchronously and navigates", %{conn: conn} do
      alias Phoenix.LiveViewTest, as: LVT

      stub_full_import()

      [first | _] = Map.get(release_group_search_results(), "release-groups")
      first_id = first["id"]

      {:ok, view, _html} = LVT.live(conn, ~p"/collection/import")

      view
      |> LVT.form("#import_form", %{"mb_query" => "Marillion Marbles"})
      |> LVT.render_change()

      view
      |> LVT.element("#musicbrainz_#{first_id} a", "CD")
      |> LVT.render_click()

      view
      |> LVT.element("button", "Import 1 record")
      |> LVT.render_click()

      {path, _flash} = assert_redirect(view, 2_000)
      "/collection/" <> record_id = path

      record = MusicLibrary.Records.get_record!(record_id)

      assert record.musicbrainz_id == first_id
      assert record.title == "Marbles"
      assert record.format == :cd
      refute is_nil(record.purchased_at)

      {:ok, resized_cover_data} = Image.resize(marbles_cover_data())
      assets = Assets.get(record.cover_hash)
      assert assets.content == resized_cover_data

      refute_enqueued(worker: ImportFromMusicbrainzReleaseGroup)
    end

    test "enqueues one job per cart item for 2+ items and closes modal", %{conn: conn} do
      stub_release_group_search()

      [first, second | _] = Map.get(release_group_search_results(), "release-groups")
      first_id = first["id"]
      second_id = second["id"]

      conn
      |> visit(~p"/collection/import")
      |> fill_in("Search for a record", with: "Marillion Marbles")
      |> click_link("#musicbrainz_#{first_id} a", "CD")
      |> click_link("#musicbrainz_#{second_id} a", "Vinyl")
      |> click_button("Import 2 records")
      |> assert_has("p", text: "Importing 2 records in the background...")

      assert_enqueued(
        worker: ImportFromMusicbrainzReleaseGroup,
        args: %{"release_group_id" => first_id, "format" => "cd"}
      )

      assert_enqueued(
        worker: ImportFromMusicbrainzReleaseGroup,
        args: %{"release_group_id" => second_id, "format" => "vinyl"}
      )

      assert MusicLibrary.Repo.all(Record) == []
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

  describe "Add via barcode scan" do
    test "tracks the camera status", %{conn: conn} do
      session =
        conn
        |> visit(~p"/collection/scan")
        |> assert_has("h1", "Scan one or more barcodes")
        |> assert_has("button#camera-button")

      session
      |> trigger_hook("#barcode-scanner", "camera_denied")
      |> assert_has("button#camera-button")
      |> refute_has("video#camera-preview")

      session
      |> trigger_hook("#barcode-scanner", "camera_allowed")
      |> refute_has("button#camera-button")
      |> assert_has("video#camera-preview")
    end

    test "adds a record after scanning", %{conn: conn} do
      barcode = "5037300650128"
      releases = releases(:marbles)

      release = release(:marbles)
      release_id = release_id(:marbles)

      release_group = release_group(:marbles)
      release_group_id = release_group["id"]
      release_group_releases = release_group_releases(:marbles)

      cover_data = marbles_cover_data()

      Test.stub(MusicBrainz.API, fn conn ->
        case conn.path_info do
          [_ws, _version, "release-group", ^release_group_id] ->
            Test.json(conn, release_group)

          [_ws, _version, "release", ^release_id] ->
            Test.json(conn, release)

          [_ws, _version, "release"] ->
            if conn.params["query"] do
              # barcode scan
              Test.json(conn, releases)
            else
              # Search by release group ID
              Test.json(conn, release_group_releases)
            end

          [_release_group, ^release_group_id, "front"] ->
            Plug.Conn.send_resp(conn, 200, cover_data)
        end
      end)

      conn
      |> visit(~p"/collection/scan")
      |> trigger_hook("#barcode-scanner", "barcode_scanned", %{"number" => barcode})
      |> assert_has("#cart-items", text: "Marbles")
      |> assert_has("span", "New")
      |> click_button("Add 1 release")

      [record] = MusicLibrary.Repo.all(MusicLibrary.Records.Record)

      assert record.musicbrainz_id == release_group_id
      assert record.title == "Marbles"
      assert record.release_date == "2004-05-03"
      assert record.format == :cd
      assert record.musicbrainz_data == release_group
      assert record.selected_release_id == "d3f9b9e2-73f5-4b47-a2a7-2c2199aad608"

      assert record.genres == [
               "alternative rock",
               "art rock",
               "baroque pop",
               "pop rock",
               "progressive rock",
               "psychedelic pop",
               "rock"
             ]

      assert record.cover_hash ==
               "E7238C742E5B8711FC5BFF01A4A1F727D9E404A4D1420429A6B37ABFFC0B5960"

      asset = Assets.get(record.cover_hash)
      {:ok, resized_cover_data} = Image.resize(cover_data)

      assert asset.content == resized_cover_data

      assert record.inserted_at !== nil
      assert record.updated_at !== nil
      assert record.purchased_at !== nil

      [marillion] = record.artists

      assert %MusicLibrary.Artists.Artist{
               name: "Marillion",
               sort_name: "Marillion",
               disambiguation: "British progressive rock band",
               musicbrainz_id: "1932f5b6-0b7b-4050-b1df-833ca89e5f44"
             } = marillion
    end
  end

  defp cover_url(record, width) do
    transform = %Transform{hash: record.cover_hash, width: width}
    payload = Transform.encode!(transform)
    ~p"/assets/#{payload}"
  end
end
