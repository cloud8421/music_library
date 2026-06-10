defmodule MusicLibraryWeb.ScrobbleLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  alias MusicBrainz.Fixtures.ReleaseGroup
  alias Req.Test

  setup do
    Test.set_req_test_to_shared()

    on_exit(fn ->
      Test.stub(MusicBrainz.API, nil)
    end)

    :ok
  end

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

  defp stub_search_failure(_) do
    Test.stub(MusicBrainz.API, fn conn ->
      case conn.request_path do
        "/ws/2/release-group" ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(503, ~s({"error":"service unavailable"}))

        _ ->
          Test.json(conn, %{})
      end
    end)

    :ok
  end

  defp stub_search_exit(_) do
    Test.stub(MusicBrainz.API, fn _conn ->
      raise "search failed"
    end)

    :ok
  end

  defp stub_delayed_search_results(_) do
    Test.stub(MusicBrainz.API, fn conn ->
      case {conn.request_path, conn.query_params["query"]} do
        {"/ws/2/release-group", "slow"} ->
          Process.sleep(250)
          Test.json(conn, release_group_search_results("Slow Result"))

        {"/ws/2/release-group", "marbles"} ->
          Test.json(conn, ReleaseGroup.release_group_search_results())

        {"/ws/2/release-group", _query} ->
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
      |> render_async()
      |> assert_has("h3", "Release Groups")
      |> assert_has("p", "Marbles")
    end

    test "search with results shows release groups", %{conn: conn} do
      conn
      |> visit(~p"/scrobble?#{[query: "marbles"]}")
      |> render_async()
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

      session =
        conn
        |> visit(~p"/scrobble?#{[query: "marbles"]}")
        |> render_async()

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
      |> render_async()
      |> assert_has("p", "No release groups found")
    end
  end

  describe "Index loading state" do
    setup [:stub_delayed_search_results]

    test "shows loading state while search is in flight", %{conn: conn} do
      conn
      |> visit(~p"/scrobble")
      |> search("slow")
      |> assert_has("p", "Searching...")
      |> render_async(500)
      |> assert_has("p", "Slow Result")
    end

    test "ignores stale results from superseded searches", %{conn: conn} do
      session =
        conn
        |> visit(~p"/scrobble")
        |> search("slow")
        |> search("marbles")
        |> render_async(500)

      session
      |> assert_has("p", "Marbles")
      |> refute_has("p", "Slow Result")
    end
  end

  describe "Index search failure" do
    @tag :capture_log
    setup [:stub_search_failure]

    test "shows failure message when MusicBrainz returns an error", %{conn: conn} do
      conn
      |> visit(~p"/scrobble?#{[query: "marbles"]}")
      |> render_async()
      |> assert_has("*", "Failed to search for release groups")
    end
  end

  describe "Index search task exit" do
    @tag :capture_log
    setup [:stub_search_exit]

    test "shows failure message when the search task exits", %{conn: conn} do
      conn
      |> visit(~p"/scrobble?#{[query: "marbles"]}")
      |> render_async()
      |> assert_has("*", "Failed to search for release groups")
    end
  end

  defp search(session, query) do
    unwrap(session, fn view ->
      view
      |> form("form[phx-change='search']:not([phx-target])", %{query: query})
      |> render_change()
    end)
  end

  defp release_group_search_results(title) do
    %{
      "count" => 1,
      "release-groups" => [
        %{
          "id" => "00000000-0000-0000-0000-000000000001",
          "primary-type" => "Album",
          "title" => title,
          "first-release-date" => "2024-01-01",
          "artist-credit" => [
            %{
              "artist" => %{"name" => "Test Artist"},
              "joinphrase" => ""
            }
          ]
        }
      ]
    }
  end
end
