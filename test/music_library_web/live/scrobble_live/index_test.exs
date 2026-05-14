defmodule MusicLibraryWeb.ScrobbleLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  alias MusicBrainz.Fixtures.ReleaseGroup
  alias Req.Test

  defp stub_search_results(_) do
    Test.stub(MusicBrainz.API, fn conn ->
      case conn.request_path do
        "/ws/2/release-group" ->
          Test.json(conn, ReleaseGroup.release_group_search_results())

        _ ->
          Test.json(conn, %{})
      end
    end)

    :ok
  end

  defp stub_empty_search_results(_) do
    Test.stub(MusicBrainz.API, fn conn ->
      case conn.request_path do
        "/ws/2/release-group" ->
          Test.json(conn, %{"count" => 0, "release-groups" => []})

        _ ->
          Test.json(conn, %{})
      end
    end)

    :ok
  end

  describe "Index" do
    setup [:stub_search_results]

    test "renders search page with form", %{conn: conn} do
      conn
      |> visit(~p"/scrobble")
      |> assert_has("form[phx-submit='search']:not([phx-target])")
    end

    test "shows connect Last.fm button when not authenticated", %{conn: conn} do
      conn
      |> visit(~p"/scrobble")
      |> assert_has("a", "Connect your Last.fm account")
    end

    test "pre-fills search and loads results from query param", %{conn: conn} do
      conn
      |> visit(~p"/scrobble?#{[query: "marbles"]}")
      |> assert_has("input[value='marbles']")
      |> assert_has("h3", "Release Groups")
      |> assert_has("p", "Marbles")
    end

    test "search with results shows release groups", %{conn: conn} do
      conn
      |> visit(~p"/scrobble?#{[query: "marbles"]}")
      |> assert_has("h3", "Release Groups")
      |> assert_has("p", "Marbles")
    end

    test "search with empty query does not trigger search", %{conn: conn} do
      conn
      |> visit(~p"/scrobble?#{[query: ""]}")
      |> refute_has("h3", "Release Groups")
    end

    test "clicking a release group navigates to /scrobble/:rg_id", %{conn: conn} do
      release_group_id = ReleaseGroup.release_group_id(:marbles)

      session = visit(conn, ~p"/scrobble?#{[query: "marbles"]}")

      session
      |> click_link("a[href='/scrobble/#{release_group_id}']", "Marbles")
      |> assert_path(~p"/scrobble/#{release_group_id}")
    end
  end

  describe "Index with no results" do
    setup [:stub_empty_search_results]

    test "shows no results message", %{conn: conn} do
      conn
      |> visit(~p"/scrobble?#{[query: "nonexistent"]}")
      |> assert_has("p", "No release groups found")
    end
  end
end
