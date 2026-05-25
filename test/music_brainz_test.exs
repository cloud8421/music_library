defmodule MusicBrainzTest do
  use ExUnit.Case, async: true

  import MusicBrainz.Fixtures.Release
  import MusicBrainz.Fixtures.ReleaseGroup

  alias MusicBrainz.ReleaseGroupSearchResult

  describe "search_release_group/2" do
    test "returns results with correct limit and offset" do
      results = release_group_search_results()

      expected_results =
        Enum.map(results["release-groups"], &ReleaseGroupSearchResult.from_api_response/1)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, results)
      end)

      assert {:ok, result} =
               MusicBrainz.search_release_group("Marillion", limit: 20, offset: 10)

      assert result.release_groups == expected_results
      assert result.total_count == 437
    end
  end

  describe "search_release_by_barcode/1" do
    test "returns releases belonging to the same release group" do
      barcode = "5052205070023"

      releases =
        releases(:queen_greatest_hits)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, releases)
      end)

      assert {:ok, results} =
               MusicBrainz.search_release_by_barcode(barcode)

      assert Enum.all?(results, fn result ->
               result.release_group.id == "69ce61c8-127f-3809-95d8-62fdf3ae1347" &&
                 result.release_group.title == "Greatest Hits"
             end)
    end
  end

  describe "get_all_releases/1" do
    @release_group_id "ae504fd6-8498-463e-8d96-14f9e11d1863"

    defp release_page(count) do
      releases =
        for i <- 1..count do
          %{"id" => "rel-#{:erlang.unique_integer([:positive])}", "title" => "Release #{i}"}
        end

      %{"releases" => releases, "release-offset" => 0, "release-count" => count}
    end

    test "single-page response returns the whole list" do
      page = release_page(25)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["offset"] == "0"
        assert conn.query_params["limit"] == "100"
        Req.Test.json(conn, page)
      end)

      assert {:ok, releases} = MusicBrainz.get_all_releases(@release_group_id)
      assert releases == page["releases"]
    end

    test "multi-page response accumulates pages in order until a short page is returned" do
      full_page = release_page(100)
      tail_page = release_page(42)

      {:ok, agent} = Agent.start_link(fn -> [] end)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        Agent.update(agent, fn calls -> calls ++ [conn.query_params["offset"]] end)

        case conn.query_params["offset"] do
          "0" -> Req.Test.json(conn, full_page)
          "100" -> Req.Test.json(conn, tail_page)
        end
      end)

      assert {:ok, releases} = MusicBrainz.get_all_releases(@release_group_id)
      assert Enum.count_until(releases, 143) == 142
      assert releases == full_page["releases"] ++ tail_page["releases"]
      assert Agent.get(agent, & &1) == ["0", "100"]
    end

    test "exact-boundary page (equal to limit) triggers an extra fetch that returns empty" do
      full_page = release_page(100)
      empty_page = %{"releases" => []}

      Req.Test.stub(MusicBrainz.API, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        case conn.query_params["offset"] do
          "0" -> Req.Test.json(conn, full_page)
          "100" -> Req.Test.json(conn, empty_page)
        end
      end)

      assert {:ok, releases} = MusicBrainz.get_all_releases(@release_group_id)
      assert Enum.count_until(releases, 101) == 100
      assert releases == full_page["releases"]
    end

    test "empty response returns an empty list" do
      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, %{"releases" => []})
      end)

      assert {:ok, releases} = MusicBrainz.get_all_releases(@release_group_id)
      assert releases == []
    end

    @tag :capture_log
    test "error on a later page is returned immediately" do
      full_page = release_page(100)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        case conn.query_params["offset"] do
          "0" ->
            Req.Test.json(conn, full_page)

          "100" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(503, ~s({"error":"service unavailable"}))
        end
      end)

      assert {:error, %MusicBrainz.API.ErrorResponse{status: 503, kind: :rate_limit}} =
               MusicBrainz.get_all_releases(@release_group_id)
    end
  end
end
