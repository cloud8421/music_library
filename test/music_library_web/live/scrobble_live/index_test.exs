defmodule MusicLibraryWeb.ScrobbleLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest, only: [render: 1, render_submit: 1, render_click: 3, form: 3]

  alias MusicBrainz.Fixtures.ReleaseGroup

  defp stub_search_results(_) do
    Req.Test.stub(MusicBrainz.API, fn conn ->
      case conn.request_path do
        "/ws/2/release-group" ->
          Req.Test.json(conn, ReleaseGroup.release_group_search_results())

        "/ws/2/release" ->
          Req.Test.json(conn, ReleaseGroup.release_group_releases(:marbles))

        _ ->
          Req.Test.json(conn, %{})
      end
    end)

    :ok
  end

  defp stub_empty_search_results(_) do
    Req.Test.stub(MusicBrainz.API, fn conn ->
      case conn.request_path do
        "/ws/2/release-group" ->
          Req.Test.json(conn, %{"count" => 0, "release-groups" => []})

        _ ->
          Req.Test.json(conn, %{})
      end
    end)

    :ok
  end

  describe "Index" do
    setup [:stub_search_results]

    test "renders search page with form", %{conn: conn} do
      conn
      |> visit(~p"/scrobble")
      |> assert_has("form[phx-submit='search']")
    end

    test "shows connect Last.fm button when not authenticated", %{conn: conn} do
      conn
      |> visit(~p"/scrobble")
      |> assert_has("a", "Connect your Last.fm account")
    end

    test "pre-fills search and loads results from query param", %{conn: conn} do
      session = visit(conn, ~p"/scrobble?#{[query: "marbles"]}")

      session
      |> unwrap(fn view ->
        render(view)
      end)
      |> assert_has("input[value='marbles']")
      |> assert_has("h3", "Release Groups")
      |> assert_has("p", "Marbles")
    end

    test "search with results shows release groups", %{conn: conn} do
      session = visit(conn, ~p"/scrobble")

      session
      |> unwrap(fn view ->
        view
        |> form("form[phx-submit='search']", %{query: "marbles"})
        |> render_submit()

        render(view)
      end)
      |> assert_has("h3", "Release Groups")
      |> assert_has("p", "Marbles")
    end

    test "search with empty query does not trigger search", %{conn: conn} do
      session = visit(conn, ~p"/scrobble")

      session
      |> unwrap(fn view ->
        view
        |> form("form[phx-submit='search']", %{query: ""})
        |> render_submit()
      end)
      |> refute_has("h3", "Release Groups")
    end

    test "select release group shows releases", %{conn: conn} do
      release_group_id = ReleaseGroup.release_group_id(:marbles)

      session = visit(conn, ~p"/scrobble")

      session
      |> unwrap(fn view ->
        view
        |> form("form[phx-submit='search']", %{query: "marbles"})
        |> render_submit()

        render(view)

        view
        |> render_click("select_release_group", %{
          "release_group_id" => release_group_id
        })

        render(view)
      end)
      |> assert_has("h3", "Releases for")
      |> assert_has("button", "Back")
    end

    test "clear selection goes back to release groups", %{conn: conn} do
      release_group_id = ReleaseGroup.release_group_id(:marbles)

      session = visit(conn, ~p"/scrobble")

      session
      |> unwrap(fn view ->
        view
        |> form("form[phx-submit='search']", %{query: "marbles"})
        |> render_submit()

        render(view)

        view
        |> render_click("select_release_group", %{
          "release_group_id" => release_group_id
        })

        render(view)

        # Click back button
        view
        |> render_click("clear_selection", %{})
      end)
      |> assert_has("h3", "Release Groups")
      |> refute_has("h3", "Releases for")
    end
  end

  describe "Index with no results" do
    setup [:stub_empty_search_results]

    test "shows no results message", %{conn: conn} do
      session = visit(conn, ~p"/scrobble")

      session
      |> unwrap(fn view ->
        view
        |> form("form[phx-submit='search']", %{query: "nonexistent"})
        |> render_submit()

        render(view)
      end)
      |> assert_has("p", "No release groups found")
    end
  end
end
