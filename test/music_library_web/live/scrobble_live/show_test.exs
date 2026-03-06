defmodule MusicLibraryWeb.ScrobbleLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest, only: [render_click: 3]

  alias MusicBrainz.Fixtures.Release, as: ReleaseFixtures
  alias MusicLibrary.Secrets

  @release_id ReleaseFixtures.release_id(:marbles)

  defp stub_musicbrainz_release(_) do
    Req.Test.stub(MusicBrainz.API, fn conn ->
      case conn.request_path do
        "/ws/2/release/" <> _id ->
          Req.Test.json(conn, ReleaseFixtures.release_with_media(:marbles))

        _ ->
          Req.Test.json(conn, %{})
      end
    end)

    :ok
  end

  defp stub_musicbrainz_release_error(_) do
    Req.Test.stub(MusicBrainz.API, fn conn ->
      Plug.Conn.send_resp(conn, 404, "Not Found")
    end)

    :ok
  end

  defp stub_lastfm_scrobble(_) do
    Req.Test.stub(LastFm.API, fn conn ->
      Req.Test.json(conn, %{"scrobbles" => %{"@attr" => %{"accepted" => 1}}})
    end)

    :ok
  end

  defp store_lastfm_session_key(_) do
    Secrets.store("last_fm_session_key", "test_session_key")
    :ok
  end

  describe "Show" do
    setup [:stub_musicbrainz_release]

    test "renders release details", %{conn: conn} do
      conn
      |> visit(~p"/scrobble/#{@release_id}")
      |> assert_has("h2", "Marbles")
      |> assert_has("a", "Back to search")
    end

    test "shows Last.fm not connected alert when no session key", %{conn: conn} do
      conn
      |> visit(~p"/scrobble/#{@release_id}")
      |> assert_has("div", "You need to connect your Last.fm account")
    end

    test "displays tracks", %{conn: conn} do
      conn
      |> visit(~p"/scrobble/#{@release_id}")
      |> assert_has("h3", "Tracks")
    end
  end

  describe "Show with Last.fm connected" do
    setup [:stub_musicbrainz_release, :stub_lastfm_scrobble, :store_lastfm_session_key]

    test "does not show Last.fm not connected alert", %{conn: conn} do
      conn
      |> visit(~p"/scrobble/#{@release_id}")
      |> refute_has("[data-part='title']", "Last.fm not connected")
    end

    test "scrobble full release", %{conn: conn} do
      session = visit(conn, ~p"/scrobble/#{@release_id}")

      session
      |> unwrap(fn view ->
        render_click(view, "scrobble_release", %{})
      end)
      |> assert_has("#toast-group", "Release scrobbled successfully")
    end

    test "scrobble single medium", %{conn: conn} do
      session = visit(conn, ~p"/scrobble/#{@release_id}")

      session
      |> unwrap(fn view ->
        render_click(view, "scrobble_medium", %{"medium_number" => "1"})
      end)
      |> assert_has("#toast-group", "Disc scrobbled successfully")
    end

    test "toggle track selection", %{conn: conn} do
      session = visit(conn, ~p"/scrobble/#{@release_id}")

      # Get a track ID from the rendered page, then toggle it
      session
      |> unwrap(fn view ->
        # Toggle a track on
        render_click(view, "toggle_track", %{"track-id" => "some-track-id"})
      end)
    end

    test "scrobble selected tracks", %{conn: conn} do
      release_data = ReleaseFixtures.release_with_media(:marbles)
      first_track = release_data["media"] |> List.first() |> Map.get("tracks") |> List.first()
      track_id = first_track["id"]

      session = visit(conn, ~p"/scrobble/#{@release_id}")

      session
      |> unwrap(fn view ->
        # Select a track first
        render_click(view, "toggle_track", %{"track-id" => track_id})
        # Then scrobble selected
        render_click(view, "scrobble_selected_tracks", %{})
      end)
      |> assert_has("#toast-group", "Selected tracks scrobbled successfully")
    end
  end

  describe "Show with failed release fetch" do
    setup [:stub_musicbrainz_release_error]

    test "redirects to scrobble index with error", %{conn: conn} do
      conn
      |> visit(~p"/scrobble/#{@release_id}")
      |> assert_path(~p"/scrobble")
    end
  end
end
