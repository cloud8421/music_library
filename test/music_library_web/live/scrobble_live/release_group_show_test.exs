defmodule MusicLibraryWeb.ScrobbleLive.ReleaseGroupShowTest do
  use MusicLibraryWeb.ConnCase

  alias MusicBrainz.Fixtures.ReleaseGroup
  alias Req.Test

  @rg_id ReleaseGroup.release_group_id(:marbles)

  defp stub_release_group(_) do
    Test.stub(MusicBrainz.API, fn conn ->
      case conn.request_path do
        "/ws/2/release-group/" <> _id ->
          Test.json(conn, ReleaseGroup.release_group(:marbles))

        "/ws/2/release" ->
          Test.json(conn, ReleaseGroup.release_group_releases(:marbles))

        _ ->
          Test.json(conn, %{})
      end
    end)

    :ok
  end

  defp stub_release_group_error(_) do
    Test.stub(MusicBrainz.API, fn conn ->
      Plug.Conn.send_resp(conn, 500, "Internal Server Error")
    end)

    :ok
  end

  describe "Show" do
    setup [:stub_release_group]

    test "renders release-group title", %{conn: conn} do
      conn
      |> visit(~p"/scrobble/#{@rg_id}")
      |> assert_has("h1", text: "Marbles", timeout: 200)
    end

    test "renders list of releases with link targets", %{conn: conn} do
      conn
      |> visit(~p"/scrobble/#{@rg_id}")
      |> assert_has("a[href^='/scrobble/#{@rg_id}/releases/']", timeout: 200)
    end

    test "back link targets /scrobble", %{conn: conn} do
      conn
      |> visit(~p"/scrobble/#{@rg_id}")
      |> assert_has("a[href='/scrobble']", text: "Back to search")
    end

    test "sets the page title from the loaded release group", %{conn: conn} do
      {:ok, view, _html} = Phoenix.LiveViewTest.live(conn, ~p"/scrobble/#{@rg_id}")
      render_async(view)

      assert Phoenix.LiveViewTest.page_title(view) ==
               "Marillion - Marbles · Release Group · Scrobble Anything"
    end
  end

  describe "fetch failure" do
    setup [:stub_release_group_error]

    @tag :capture_log
    test "shows toast and redirects to /scrobble", %{conn: conn} do
      conn
      |> visit(~p"/scrobble/#{@rg_id}")
      |> assert_has("#toast-group", text: "Error loading release group", timeout: 200)
      |> assert_path(~p"/scrobble")
    end
  end
end
