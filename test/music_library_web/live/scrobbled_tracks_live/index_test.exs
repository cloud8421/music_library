defmodule MusicLibraryWeb.ScrobbledTracksLiveTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.ScrobbledTracksFixtures

  alias MusicLibrary.ListeningStats

  @valid_track_attrs %{
    title: "Updated Track Title",
    artist: %{name: "Updated Artist", musicbrainz_id: "9a5cf59b-5da0-4021-b885-b6b78dd6886e"},
    album: %{title: "Updated Album", musicbrainz_id: "9a5cf59b-5da0-4021-b885-b6b78dd6886f"},
    cover_url: "https://example.com/updated-cover.jpg"
  }

  defp create_track(_) do
    track = track_fixture()
    %{track: track}
  end

  defp create_multiple_tracks(_) do
    tracks = create_test_tracks(5)
    %{tracks: tracks}
  end

  describe "Index" do
    setup [:create_track]

    test "lists scrobbled tracks", %{conn: conn, track: track} do
      conn
      |> visit(~p"/scrobbled-tracks")
      |> assert_has("p", track.title)
      |> assert_has("p", track.artist.name)
      |> assert_has("p", track.album.title)
    end

    test "shows empty state when no tracks", %{conn: conn} do
      ListeningStats.delete_track(track_fixture())

      conn
      |> visit(~p"/scrobbled-tracks")
      |> assert_has("p", "No scrobbled tracks found")
    end
  end

  describe "Search functionality" do
    setup [:create_multiple_tracks]

    test "filters results by search query", %{conn: conn} do
      track_fixture(%{title: "Unique Track Title"})

      conn
      |> visit(~p"/scrobbled-tracks?#{[query: "Unique Track"]}")
      |> assert_has("p", "Unique Track Title")
    end
  end

  describe "Edit track" do
    setup [:create_track]

    test "updates track successfully", %{conn: conn, track: track} do
      session =
        conn
        |> visit(~p"/scrobbled-tracks/#{track.scrobbled_at_uts}/edit")
        |> assert_has("h1", "Edit Scrobbled Track")
        |> assert_path(~p"/scrobbled-tracks/#{track.scrobbled_at_uts}/edit")

      # Submit valid changes
      session
      |> fill_in("Track Title", with: @valid_track_attrs.title)
      |> fill_in("Artist Name", with: @valid_track_attrs.artist.name)
      |> fill_in("Artist MusicBrainz ID", with: @valid_track_attrs.artist.musicbrainz_id)
      |> fill_in("Album Title", with: @valid_track_attrs.album.title)
      |> fill_in("Album MusicBrainz ID", with: @valid_track_attrs.album.musicbrainz_id)
      |> fill_in("Cover Image URL (optional)", with: @valid_track_attrs.cover_url)
      |> click_button("Update Track")
      |> assert_has("p", "Track updated successfully")
      |> assert_has("p", "Updated Track Title")
    end

    test "shows validation errors", %{conn: conn, track: track} do
      conn
      |> visit(~p"/scrobbled-tracks/#{track.scrobbled_at_uts}/edit")
      |> fill_in("Track Title", with: "")
      |> click_button("Update Track")
      |> assert_has("[data-part='error']", "can't be blank")
    end
  end

  describe "Delete track" do
    setup [:create_track]

    test "deletes a scrobbled track from the listing", %{conn: conn, track: track} do
      conn
      |> visit(~p"/scrobbled-tracks")
      |> assert_has("p", track.title)
      |> click_button("button[data-confirm='Are you sure?']", "Delete")
      |> refute_has("p", track.title)
      |> render_async()

      assert_raise Ecto.NoResultsError, fn ->
        ListeningStats.get_track!(track.scrobbled_at_uts)
      end
    end
  end

  describe "Pagination" do
    test "navigates to next page", %{conn: conn} do
      create_test_tracks(21)

      conn
      |> visit(~p"/scrobbled-tracks")
      |> assert_has("a", "Next")
      |> assert_has("#bottom_pagination")
      |> click_link("a[href*='page=2']", "2")
    end
  end

  describe "URL parameter handling" do
    test "handles query parameter", %{conn: conn} do
      track_fixture(%{title: "Special Track"})

      conn
      |> visit(~p"/scrobbled-tracks?query=Special")
      |> assert_has("p", "Special Track")
    end

    test "handles page parameter", %{conn: conn} do
      create_test_tracks(5)

      # Just verify the page loads successfully
      visit(conn, ~p"/scrobbled-tracks?page=2&page_size=3")
    end

    test "handles order parameter", %{conn: conn} do
      create_test_tracks(5)

      # Just verify the page loads successfully with order parameter
      visit(conn, ~p"/scrobbled-tracks?order=title")
    end

    test "handles invalid parameters gracefully", %{conn: conn} do
      create_test_tracks(5)

      # Just verify the page loads successfully with invalid parameters
      visit(conn, ~p"/scrobbled-tracks?page=invalid&order=invalid")
    end
  end

  describe "Error handling" do
    test "handles non-existent track edit gracefully", %{conn: conn} do
      invalid_id = 999_999_999

      assert_raise Ecto.NoResultsError, fn ->
        visit(conn, ~p"/scrobbled-tracks/#{invalid_id}/edit")
      end
    end
  end
end
