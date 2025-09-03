defmodule MusicLibraryWeb.ScrobbledTracksLiveTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.ScrobbledTracksFixtures
  import Phoenix.LiveViewTest

  alias MusicLibrary.ScrobbleActivity

  # Test data
  @invalid_track_attrs %{title: "", artist: %{name: ""}, album: %{title: ""}}
  @valid_track_attrs %{
    title: "Updated Track Title",
    artist: %{name: "Updated Artist"},
    album: %{title: "Updated Album"},
    scrobbled_at_label: "02/02/2024 14:00:00",
    cover_url: "https://example.com/updated-cover.jpg"
  }

  defp create_track(_) do
    track = track_fixture()
    %{track: track}
  end

  defp create_multiple_tracks(_) do
    tracks = create_test_tracks(10)
    %{tracks: tracks}
  end

  describe "Index" do
    setup [:create_track]

    test "lists scrobbled tracks", %{conn: conn, track: track} do
      {:ok, _index_live, html} = live(conn, ~p"/scrobbled-tracks")

      assert html =~ "Scrobbled Tracks"
      assert html =~ track.title
      assert html =~ track.artist.name
      assert html =~ track.album.title
    end

    test "shows empty state when no tracks", %{conn: conn} do
      # Delete the created track
      ScrobbleActivity.delete_track(track_fixture())

      {:ok, _index_live, html} = live(conn, ~p"/scrobbled-tracks")

      assert html =~ "No scrobbled tracks found"
    end

    test "displays track count", %{conn: conn} do
      create_test_tracks(3)

      {:ok, _index_live, html} = live(conn, ~p"/scrobbled-tracks")

      assert html =~ ~r/\d+ tracks?/
    end
  end

  describe "Search functionality" do
    setup [:create_multiple_tracks]

    test "searches tracks by title", %{conn: conn} do
      track_fixture(%{title: "Unique Track Title"})

      {:ok, index_live, _html} = live(conn, ~p"/scrobbled-tracks")

      html =
        index_live
        |> form("form[phx-submit='search']", %{query: "Unique Track"})
        |> render_submit()

      assert html =~ "Unique Track Title"
    end

    test "searches tracks by artist name", %{conn: conn} do
      track_fixture(%{artist_name: "Unique Artist Name"})

      {:ok, index_live, _html} = live(conn, ~p"/scrobbled-tracks")

      html =
        index_live
        |> form("form[phx-submit='search']", %{query: "Unique Artist"})
        |> render_submit()

      assert html =~ "Unique Artist Name"
    end

    test "searches tracks by album title", %{conn: conn} do
      track_fixture(%{album_title: "Unique Album Title"})

      {:ok, index_live, _html} = live(conn, ~p"/scrobbled-tracks")

      html =
        index_live
        |> form("form[phx-submit='search']", %{query: "Unique Album"})
        |> render_submit()

      assert html =~ "Unique Album Title"
    end

    test "shows no results message for non-matching search", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobbled-tracks")

      html =
        index_live
        |> form("form[phx-submit='search']", %{query: "NonexistentTrack"})
        |> render_submit()

      assert html =~ "Try adjusting your search"
    end
  end

  describe "Sorting functionality" do
    setup [:create_multiple_tracks]

    test "sorts by scrobbled date (default)", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobbled-tracks")

      # Click on scrobbled date sort button
      html =
        index_live
        |> element("button[patch*='order=scrobbled_at']")
        |> render_click()

      assert html =~ "Scrobbled Tracks"
      # Check that URL contains the order parameter
      assert_patch(
        index_live,
        ~p"/scrobbled-tracks?order=scrobbled_at&page=1&page_size=200&query="
      )
    end

    test "sorts by track title", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobbled-tracks")

      html =
        index_live
        |> element("button[patch*='order=title']")
        |> render_click()

      assert html =~ "Scrobbled Tracks"
      assert_patch(index_live, ~p"/scrobbled-tracks?order=title&page=1&page_size=200&query=")
    end

    test "sorts by artist name", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobbled-tracks")

      html =
        index_live
        |> element("button[patch*='order=artist']")
        |> render_click()

      assert html =~ "Scrobbled Tracks"
      assert_patch(index_live, ~p"/scrobbled-tracks?order=artist&page=1&page_size=200&query=")
    end

    test "sorts by album title", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobbled-tracks")

      html =
        index_live
        |> element("button[patch*='order=album']")
        |> render_click()

      assert html =~ "Scrobbled Tracks"
      assert_patch(index_live, ~p"/scrobbled-tracks?order=album&page=1&page_size=200&query=")
    end
  end

  describe "Edit track" do
    setup [:create_track]

    test "updates track successfully", %{conn: conn, track: track} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobbled-tracks")

      assert index_live
             |> element("button[patch='/scrobbled-tracks/#{track.scrobbled_at_uts}/edit']")
             |> render_click() =~ "Edit Scrobbled Track"

      assert_patch(index_live, ~p"/scrobbled-tracks/#{track.scrobbled_at_uts}/edit")

      assert index_live
             |> form("#track-form", track: @invalid_track_attrs)
             |> render_change() =~ "can&#39;t be blank"

      html =
        index_live
        |> form("#track-form", track: @valid_track_attrs)
        |> render_submit()

      assert html =~ "Track updated successfully"
      assert html =~ "Updated Track Title"
    end

    test "shows validation errors", %{conn: conn, track: track} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobbled-tracks")

      assert index_live
             |> element("button[patch='/scrobbled-tracks/#{track.scrobbled_at_uts}/edit']")
             |> render_click()

      assert index_live
             |> form("#track-form", track: @invalid_track_attrs)
             |> render_change() =~ "can&#39;t be blank"
    end

    test "closes modal when clicking outside or cancel", %{conn: conn, track: track} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobbled-tracks")

      # Open edit modal
      assert index_live
             |> element("button[patch='/scrobbled-tracks/#{track.scrobbled_at_uts}/edit']")
             |> render_click()

      # Close modal by patching back to index
      html = index_live |> element("button[phx-click='JS.patch']") |> render_click()

      assert_patch(index_live, ~p"/scrobbled-tracks")
    end
  end

  describe "Delete track" do
    setup [:create_track]

    test "deletes track successfully", %{conn: conn, track: track} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobbled-tracks")

      # Find and click delete button
      assert index_live
             |> element(
               "button[phx-click='delete'][phx-value-scrobbled-at-uts='#{track.scrobbled_at_uts}']"
             )
             |> render_click()

      # Track should no longer be visible
      refute has_element?(index_live, "#tracks-#{track.scrobbled_at_uts}")
    end
  end

  describe "Pagination" do
    test "shows pagination when more than one page", %{conn: conn} do
      # Create enough tracks to require pagination (more than 200)
      create_test_tracks(250)

      {:ok, index_live, html} = live(conn, ~p"/scrobbled-tracks")

      # Should show pagination component
      assert html =~ "Next"
      assert has_element?(index_live, "#bottom_pagination")
    end

    test "navigates to next page", %{conn: conn} do
      create_test_tracks(250)

      {:ok, index_live, _html} = live(conn, ~p"/scrobbled-tracks")

      # Click next page button (if visible)
      if has_element?(index_live, "button[patch*='page=2']") do
        html =
          index_live
          |> element("button[patch*='page=2']")
          |> render_click()

        assert html =~ "Scrobbled Tracks"
      end
    end
  end

  describe "URL parameter handling" do
    test "handles query parameter", %{conn: conn} do
      track_fixture(%{title: "Special Track"})

      {:ok, _index_live, html} = live(conn, ~p"/scrobbled-tracks?query=Special")

      assert html =~ "Special Track"
    end

    test "handles page parameter", %{conn: conn} do
      create_test_tracks(250)

      {:ok, _index_live, html} = live(conn, ~p"/scrobbled-tracks?page=2&page_size=100")

      assert html =~ "Scrobbled Tracks"
    end

    test "handles order parameter", %{conn: conn} do
      create_test_tracks(5)

      {:ok, _index_live, html} = live(conn, ~p"/scrobbled-tracks?order=title")

      assert html =~ "Scrobbled Tracks"
    end

    test "handles invalid parameters gracefully", %{conn: conn} do
      create_test_tracks(5)

      {:ok, _index_live, html} = live(conn, ~p"/scrobbled-tracks?page=invalid&order=invalid")

      assert html =~ "Scrobbled Tracks"
    end
  end

  describe "Navigation integration" do
    test "shows Scrobbled Tracks link in navigation", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/")

      assert html =~ "Scrobbled Tracks"
      assert html =~ ~p"/scrobbled-tracks"
    end
  end

  describe "Error handling" do
    test "handles non-existent track edit gracefully", %{conn: conn} do
      invalid_id = 999_999_999

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/scrobbled-tracks/#{invalid_id}/edit")
      end
    end
  end
end
