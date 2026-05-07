defmodule MusicLibraryWeb.UniversalSearchLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records

  setup do
    collection_record = record(%{title: "Dark Side of the Moon"})

    wishlist_record = record(%{title: "Wish You Were Here", purchased_at: nil})

    artist_record = record_with_artist("Steven Wilson", %{title: "Hand. Cannot. Erase."})

    artist_info(artist_record.artists |> List.first() |> Map.get(:musicbrainz_id), %{})

    %{
      collection_record: collection_record,
      wishlist_record: wishlist_record,
      artist_record: artist_record
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
