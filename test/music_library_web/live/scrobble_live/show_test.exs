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

  defp stub_lastfm_scrobble_error(_) do
    Req.Test.stub(LastFm.API, fn conn ->
      Req.Test.json(conn, %{"error" => 11, "message" => "Service temporarily unavailable"})
    end)

    :ok
  end

  defp store_lastfm_session_key(_) do
    Secrets.store("last_fm_session_key", "test_session_key")
    :ok
  end

  defp first_track_id do
    ReleaseFixtures.release_with_media(:marbles)
    |> Map.get("media")
    |> List.first()
    |> Map.get("tracks")
    |> List.first()
    |> Map.get("id")
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
        render_click(view, "scrobble_medium", %{"number" => "1"})
      end)
      |> assert_has("#toast-group", "Disc scrobbled successfully")
    end

    test "toggle track on and off changes button label", %{conn: conn} do
      track_id = first_track_id()

      session = visit(conn, ~p"/scrobble/#{@release_id}")

      # Toggle track on — button label changes
      session
      |> unwrap(fn view ->
        render_click(view, "toggle_track", %{"track-id" => track_id})
      end)
      |> assert_has("button", "Scrobble selected tracks")

      # Toggle track off — button label reverts
      session
      |> unwrap(fn view ->
        render_click(view, "toggle_track", %{"track-id" => track_id})
      end)
      |> assert_has("button", "Scrobble release")
    end

    test "toggle medium selects and deselects all tracks in that medium", %{conn: conn} do
      session = visit(conn, ~p"/scrobble/#{@release_id}")

      # Toggle medium 1 on — button label changes
      session
      |> unwrap(fn view ->
        render_click(view, "toggle_medium", %{"medium-number" => "1"})
      end)
      |> assert_has("button", "Scrobble selected tracks")

      # Toggle medium 1 off — button label reverts
      session
      |> unwrap(fn view ->
        render_click(view, "toggle_medium", %{"medium-number" => "1"})
      end)
      |> assert_has("button", "Scrobble release")
    end

    test "scrobble selected tracks", %{conn: conn} do
      track_id = first_track_id()

      session = visit(conn, ~p"/scrobble/#{@release_id}")

      session
      |> unwrap(fn view ->
        render_click(view, "toggle_track", %{"track-id" => track_id})
        render_click(view, "scrobble_selected_tracks", %{})
      end)
      |> assert_has("#toast-group", "Selected tracks scrobbled successfully")
    end

    test "scrobble selected tracks with no selection shows error", %{conn: conn} do
      session = visit(conn, ~p"/scrobble/#{@release_id}")

      session
      |> unwrap(fn view ->
        render_click(view, "scrobble_selected_tracks", %{})
      end)
      |> assert_has("#toast-group", "No tracks selected")
    end
  end

  describe "Show with Last.fm scrobble error" do
    setup [:stub_musicbrainz_release, :stub_lastfm_scrobble_error, :store_lastfm_session_key]

    @tag :capture_log
    test "scrobble release shows error toast on failure", %{conn: conn} do
      session = visit(conn, ~p"/scrobble/#{@release_id}")

      session
      |> unwrap(fn view ->
        render_click(view, "scrobble_release", %{})
      end)
      |> assert_has("#toast-group", "Error scrobbling release")
    end

    @tag :capture_log
    test "scrobble medium shows error toast on failure", %{conn: conn} do
      session = visit(conn, ~p"/scrobble/#{@release_id}")

      session
      |> unwrap(fn view ->
        render_click(view, "scrobble_medium", %{"number" => "1"})
      end)
      |> assert_has("#toast-group", "Error scrobbling disc")
    end

    @tag :capture_log
    test "scrobble selected tracks shows error toast on failure", %{conn: conn} do
      track_id = first_track_id()

      session = visit(conn, ~p"/scrobble/#{@release_id}")

      session
      |> unwrap(fn view ->
        render_click(view, "toggle_track", %{"track-id" => track_id})
        render_click(view, "scrobble_selected_tracks", %{})
      end)
      |> assert_has("#toast-group", "Error scrobbling selected tracks")
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
