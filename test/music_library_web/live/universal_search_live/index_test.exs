defmodule MusicLibraryWeb.UniversalSearchLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest
  import MusicLibrary.Fixtures.Records

  setup do
    # Create test data: collection and wishlist records
    collection_record = record(%{title: "Dark Side of the Moon"})

    wishlist_record =
      record(%{
        title: "Wish You Were Here",
        purchased_at: nil
      })

    artist_record =
      record_with_artist("Steven Wilson", %{
        title: "Hand. Cannot. Erase."
      })

    # Create an artist info for searchable artist
    artist_info(
      artist_record.artists |> List.first() |> Map.get(:musicbrainz_id),
      %{}
    )

    %{
      collection_record: collection_record,
      wishlist_record: wishlist_record,
      artist_record: artist_record
    }
  end

  describe "Modal visibility" do
    test "modal is hidden by default", %{conn: conn} do
      session = visit(conn, ~p"/collection")

      refute_has(session, "#universal-search-root")
    end

    test "modal opens when search button is clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/collection")

      # Open the modal by sending event to the live component
      view
      |> element("#universal-search-button")
      |> render_click()

      html = render(view)

      assert html =~ "universal-search-root"
      assert html =~ "universal-search-input"
    end

    test "modal shows empty state initially", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/collection")

      view
      |> element("#universal-search-button")
      |> render_click()

      html = render(view)

      assert html =~ "to open this search"
    end
  end

  describe "Search functionality" do
    test "shows no results message when query has no matches", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/collection")

      view
      |> element("#universal-search-button")
      |> render_click()

      # Target the universal search input specifically
      html =
        view
        |> form("#universal-search form", %{query: "nonexistent query xyz"})
        |> render_change()

      assert html =~ "No results found for &#39;nonexistent query xyz&#39;"
      assert html =~ "Add a record instead"
    end

    test "resets results when query is cleared", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/collection")

      view
      |> element("#universal-search-button")
      |> render_click()

      # First search for something
      view
      |> form("#universal-search form", %{query: "test query"})
      |> render_change()

      # Then clear the search
      html =
        view
        |> form("#universal-search form", %{query: ""})
        |> render_change()

      assert html =~ "to open this search"
      refute html =~ "No results found"
    end

    test "searches collection records", %{
      conn: conn,
      collection_record: collection_record
    } do
      {:ok, view, _html} = live(conn, ~p"/collection")

      view
      |> element("#universal-search-button")
      |> render_click()

      html =
        view
        |> form("#universal-search form", %{query: collection_record.title})
        |> render_change()

      # Should display the collection record title
      assert html =~ collection_record.title
    end

    test "searches wishlist records", %{
      conn: conn,
      wishlist_record: wishlist_record
    } do
      {:ok, view, _html} = live(conn, ~p"/collection")

      view
      |> element("#universal-search-button")
      |> render_click()

      html =
        view
        |> form("#universal-search form", %{query: wishlist_record.title})
        |> render_change()

      # Should display the wishlist record title
      assert html =~ wishlist_record.title
    end

    test "searches artists", %{
      conn: conn,
      artist_record: artist_record
    } do
      artist = List.first(artist_record.artists)

      {:ok, view, _html} = live(conn, ~p"/collection")

      view
      |> element("#universal-search-button")
      |> render_click()

      html =
        view
        |> form("#universal-search form", %{query: artist.name})
        |> render_change()

      # Should display the artist name
      assert html =~ artist.name
    end

    test "displays results count in footer", %{
      conn: conn,
      collection_record: collection_record
    } do
      {:ok, view, _html} = live(conn, ~p"/collection")

      view
      |> element("#universal-search-button")
      |> render_click()

      html =
        view
        |> form("#universal-search form", %{query: collection_record.title})
        |> render_change()

      # Should display results count
      assert html =~ "result"
    end
  end

  describe "Display and formatting" do
    test "displays keyboard shortcut hints in empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/collection")

      view
      |> element("#universal-search-button")
      |> render_click()

      html = render(view)

      # Should show keyboard shortcut info
      assert html =~ "Cmd/Ctrl+K"
    end
  end
end
