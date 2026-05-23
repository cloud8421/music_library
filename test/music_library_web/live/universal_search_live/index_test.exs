defmodule MusicLibraryWeb.UniversalSearchLive.IndexTest do
  use MusicLibraryWeb.ConnCase, async: false

  import MusicLibrary.Fixtures.Records
  import MusicLibrary.Fixtures.RecordSets

  import Phoenix.LiveViewTest,
    only: [
      render_click: 1,
      element: 2
    ]

  setup do
    collection_record = record(%{title: "Dark Side of the Moon"})

    wishlist_record = record(%{title: "Wish You Were Here", purchased_at: nil})

    artist_record = record_with_artist("Steven Wilson", %{title: "Hand. Cannot. Erase."})

    artist_info(artist_record.artists |> List.first() |> Map.get(:musicbrainz_id), %{})

    # Create a record set for navigation testing
    {:ok, record_set} =
      MusicLibrary.RecordSets.create_record_set(%{
        name: "Prog Favorites",
        description: "Best prog albums"
      })

    %{
      collection_record: collection_record,
      wishlist_record: wishlist_record,
      artist_record: artist_record,
      record_set: record_set
    }
  end

  describe "Modal visibility" do
    test "modal is hidden by default", %{conn: conn} do
      conn
      |> visit(~p"/collection")
      |> assert_has("#universal-search-root[hidden]")
    end

    test "modal opens when search button is clicked", %{conn: conn} do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> assert_has("#universal-search-root")
      |> assert_has("#universal-search-input")
    end

    test "modal shows empty state initially", %{conn: conn} do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> assert_has("p", "to open this search")
    end
  end

  describe "Search functionality" do
    test "shows no results message with quick action links when query has no matches", %{
      conn: conn
    } do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: "nonexistent query xyz")
      |> assert_has("p", "No results found for 'nonexistent query xyz'")
      |> assert_has("[role='option']", "Add to wishlist")
      |> assert_has("[role='option']", "Add to collection")
      |> assert_has("[role='option']", "Search to scrobble")
      |> assert_has("kbd", "↑")
      |> assert_has("kbd", "↓")
      |> assert_has("span", "Navigate")
    end

    test "resets results when query is cleared", %{conn: conn} do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: "test query")
      |> fill_in("Universal Search", with: "")
      |> assert_has("p", "to open this search")
    end

    test "searches collection records", %{
      conn: conn,
      collection_record: collection_record
    } do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: collection_record.title)
      |> assert_has("p", collection_record.title)
    end

    test "searches wishlist records", %{
      conn: conn,
      wishlist_record: wishlist_record
    } do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: wishlist_record.title)
      |> assert_has("p", wishlist_record.title)
    end

    test "searches artists", %{
      conn: conn,
      artist_record: artist_record
    } do
      artist = List.first(artist_record.artists)

      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: artist.name)
      |> assert_has("p", artist.name)
    end

    test "displays results count in footer", %{
      conn: conn,
      collection_record: collection_record
    } do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: collection_record.title)
      |> assert_has("div", "1 result")
    end
  end

  describe "Navigation links" do
    test "shows Collection Chat link when searching for chat", %{conn: conn} do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: "chat")
      |> assert_has("[role='option']", "Collection Chat")
    end
  end

  describe "Navigation events" do
    setup do
      Req.Test.set_req_test_to_shared()

      # Return valid-enough shapes so async task parsers don't crash
      Req.Test.stub(LastFm.API, fn conn ->
        Req.Test.json(conn, %{
          "artist" => %{
            "name" => "test",
            "mbid" => "",
            "bio" => %{"summary" => "", "content" => ""},
            "image" => [%{"#text" => "", "size" => "large"}],
            "url" => ""
          },
          "similarartists" => %{"artist" => []}
        })
      end)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, %{
          "media" => [],
          "track-count" => 0
        })
      end)

      on_exit(fn ->
        Req.Test.stub(MusicBrainz.API, nil)
        Req.Test.stub(LastFm.API, nil)
      end)

      :ok
    end

    test "navigates to collection record on click", %{
      conn: conn,
      collection_record: collection_record
    } do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: collection_record.title)
      |> unwrap(fn view ->
        view
        |> element("div[phx-click='navigate_to_record'][phx-value-type='collection']")
        |> render_click()
      end)
      |> assert_path(~p"/collection/#{collection_record.id}")
    end

    test "navigates to wishlist record on click", %{
      conn: conn,
      wishlist_record: wishlist_record
    } do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: wishlist_record.title)
      |> unwrap(fn view ->
        view
        |> element("div[phx-click='navigate_to_record'][phx-value-type='wishlist']")
        |> render_click()
      end)
      |> assert_path(~p"/wishlist/#{wishlist_record.id}")
    end

    test "navigates to artist on click", %{
      conn: conn,
      artist_record: artist_record
    } do
      artist = List.first(artist_record.artists)

      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: artist.name)
      |> unwrap(fn view ->
        view
        |> element("div[phx-click='navigate_to_artist']")
        |> render_click()
      end)
      |> assert_path(~p"/artists/#{artist.musicbrainz_id}")
    end

    test "navigates to record set on click", %{
      conn: conn,
      record_set: record_set
    } do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: record_set.name)
      |> unwrap(fn view ->
        view
        |> element("div[phx-click='navigate_to_record_set']")
        |> render_click()
      end)
      |> assert_path(~p"/record-sets/#{record_set.id}")
    end

    test "navigates via navigation link to collection chat", %{conn: conn} do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: "chat")
      |> unwrap(fn view ->
        view
        |> element("div[phx-click='navigate_to_link']")
        |> render_click()
      end)
      |> assert_path(~p"/collection", query_params: %{"chat" => "open"})
    end

    test "record sets appear in search results", %{
      conn: conn,
      record_set: record_set
    } do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: record_set.name)
      |> assert_has("p", record_set.name)
      |> assert_has("h3", "Record Sets")
    end

    test "view-all-collection navigates to collection with query param", %{conn: conn} do
      # Create 7 records sharing a common prefix so > 5 results exist
      Enum.each(1..7, fn i ->
        record(%{title: "ViewAllTest #{i}"})
      end)

      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: "ViewAllTest")
      |> click_button("button[phx-click='navigate_to_collection']", "View all")
      |> assert_path(~p"/collection", query_params: %{"query" => "ViewAllTest"})
    end

    test "view-all-wishlist navigates to wishlist with query param", %{conn: conn} do
      # Create 7 wishlist records with a common prefix
      Enum.each(1..7, fn i ->
        record(%{title: "WishlistAll #{i}", purchased_at: nil})
      end)

      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: "WishlistAll")
      |> click_button("button[phx-click='navigate_to_wishlist']", "View all")
      |> assert_path(~p"/wishlist", query_params: %{"query" => "WishlistAll"})
    end

    test "view-all-record-sets navigates to record sets with query param", %{conn: conn} do
      # Create 7 record sets with a common prefix
      Enum.each(1..7, fn i ->
        record_set(%{name: "SetAll #{i}"})
      end)

      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: "SetAll")
      |> click_button("button[phx-click='navigate_to_record_sets']", "View all")
      |> assert_path(~p"/record-sets", query_params: %{"query" => "SetAll"})
    end
  end

  describe "Keyboard navigation" do
    test "displays keyboard navigation hints when results are present", %{
      conn: conn,
      collection_record: collection_record
    } do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: collection_record.title)
      |> assert_has("kbd", "↑")
      |> assert_has("kbd", "↓")
      |> assert_has("span", "Navigate")
      |> assert_has("kbd", "Enter")
      |> assert_has("span", "Select")
    end

    test "search results have role=option for keyboard navigation", %{
      conn: conn,
      collection_record: collection_record
    } do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: collection_record.title)
      |> assert_has("[role='option']")
    end

    test "hook is attached to the universal search container", %{conn: conn} do
      conn
      |> visit(~p"/collection")
      |> assert_has("[phx-hook='UniversalSearchNavigation']")
    end
  end
end
