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
      |> refute_has("#universal-search-root")
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
      |> assert_has("p", text: "to open this search")
    end
  end

  describe "Search functionality" do
    test "shows no results message when query has no matches", %{conn: conn} do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: "nonexistent query xyz")
      |> assert_has("p", text: "No results found for 'nonexistent query xyz'")
      |> assert_has("a", text: "Add a record instead")
    end

    test "resets results when query is cleared", %{conn: conn} do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: "test query")
      |> fill_in("Universal Search", with: "")
      |> assert_has("p", text: "to open this search")
    end

    test "searches collection records", %{
      conn: conn,
      collection_record: collection_record
    } do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: collection_record.title)
      |> assert_has("p", text: collection_record.title)
    end

    test "searches wishlist records", %{
      conn: conn,
      wishlist_record: wishlist_record
    } do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: wishlist_record.title)
      |> assert_has("p", text: wishlist_record.title)
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
      |> assert_has("p", text: artist.name)
    end

    test "displays results count in footer", %{
      conn: conn,
      collection_record: collection_record
    } do
      conn
      |> visit(~p"/collection")
      |> click_button("Search (Cmd/Ctrl+K)")
      |> fill_in("Universal Search", with: collection_record.title)
      |> assert_has("div", text: "1 result")
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
      |> assert_has("kbd", text: "↑")
      |> assert_has("kbd", text: "↓")
      |> assert_has("span", text: "Navigate")
      |> assert_has("kbd", text: "Enter")
      |> assert_has("span", text: "Select")
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
      {:ok, view, _html} =
        conn
        |> visit(~p"/collection")
        |> PhoenixTest.unwrap()

      # Get the rendered HTML
      html = Phoenix.LiveViewTest.render(view)

      # Verify the hook is attached
      assert html =~ ~s(phx-hook="UniversalSearchNavigation")
    end
  end
end
