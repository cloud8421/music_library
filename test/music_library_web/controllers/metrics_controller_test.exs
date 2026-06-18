defmodule MusicLibraryWeb.MetricsControllerTest do
  use MusicLibraryWeb.ConnCase

  defp api_token do
    Application.get_env(:music_library, MusicLibraryWeb)
    |> Keyword.fetch!(:api_token)
  end

  describe "authentication" do
    test "GET /api/v1/metrics requires a bearer token", %{conn: conn} do
      assert get(conn, ~p"/api/v1/metrics").status == 401
    end

    test "GET /api/v1/metrics/overview requires a bearer token", %{conn: conn} do
      assert get(conn, ~p"/api/v1/metrics/overview").status == 401
    end
  end

  describe "GET /api/v1/metrics" do
    test "returns available metric descriptors and categories", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/metrics")

      assert %{"categories" => categories, "metrics" => metrics} = json_response(conn, 200)

      assert is_list(categories)
      assert categories != []

      for cat <- categories do
        assert is_binary(cat["id"])
        assert is_binary(cat["name"])
        assert is_integer(cat["metric_count"]) and cat["metric_count"] > 0
      end

      assert is_list(metrics)
      assert metrics != []

      for metric <- metrics do
        assert is_binary(metric["key"])
        assert is_binary(metric["name"])
        assert metric["kind"] in ["summary", "counter"]
        assert is_binary(metric["category"])
        assert is_list(metric["tags"])
        assert metric["unit"] == nil or is_binary(metric["unit"])
      end
    end
  end

  describe "GET /api/v1/metrics/overview" do
    test "returns overview with default parameters", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/metrics/overview")

      assert %{
               "generated_at" => _,
               "requested_since" => _,
               "effective_since" => _,
               "since_time" => _,
               "top" => _,
               "top_clamped" => _,
               "categories" => categories
             } = json_response(conn, 200)

      assert is_list(categories)

      for cat <- categories do
        assert is_binary(cat["id"])
        assert is_binary(cat["name"])
        assert is_list(cat["metrics"])

        for metric <- cat["metrics"] do
          assert is_binary(metric["key"])
          assert is_binary(metric["name"])
          assert metric["kind"] in ["summary", "counter"]
          assert is_list(metric["tags"])
          assert is_integer(metric["total_count"])
          assert is_list(metric["groups"])
        end
      end
    end

    test "accepts since parameter", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/metrics/overview?since=15m")

      assert %{"requested_since" => "15m"} = json_response(conn, 200)
    end

    test "returns 422 for invalid since", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/metrics/overview?since=xyz")

      assert json_response(conn, 422)["error"] =~ "Invalid since"
    end

    test "returns 422 for unknown categories", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/metrics/overview?categories=nonexistent")

      assert json_response(conn, 422)["error"] =~ "Unknown categories"
    end

    test "accepts category filter", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/metrics/overview?categories=http")

      %{"categories" => categories} = json_response(conn, 200)

      assert match?([_], categories)
      assert hd(categories)["id"] == "http"
    end

    test "accepts multiple categories", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/metrics/overview?categories=http,oban")

      %{"categories" => categories} = json_response(conn, 200)

      cat_ids = Enum.map(categories, & &1["id"])
      assert cat_ids == ["http", "oban"]
    end

    test "accepts top parameter", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/metrics/overview?top=3")

      assert %{"top" => 3} = json_response(conn, 200)
    end

    test "clamps top above max", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/metrics/overview?top=99999")

      %{"top" => top, "top_clamped" => clamped} = json_response(conn, 200)

      assert top == 50
      assert clamped
    end

    test "returns 422 for invalid top (non-integer)", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/metrics/overview?top=abc")

      assert json_response(conn, 422)["error"] =~ "Invalid top"
    end

    test "returns 422 for invalid top (zero)", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/metrics/overview?top=0")

      assert json_response(conn, 422)["error"] =~ "Invalid top"
    end

    test "returns 422 for invalid top (negative)", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/metrics/overview?top=-1")

      assert json_response(conn, 422)["error"] =~ "Invalid top"
    end

    test "empty datasets return empty groups arrays, not errors", %{conn: conn} do
      # Use a category that likely has no recent data in test
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/metrics/overview?since=15m&categories=scrobble_rules")

      %{"categories" => categories} = json_response(conn, 200)

      for cat <- categories do
        for metric <- cat["metrics"] do
          assert is_list(metric["groups"])
          assert is_integer(metric["total_count"])
        end
      end
    end

    test "clamps since above max", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/metrics/overview?since=9999h")

      %{"requested_since" => "9999h", "effective_since" => "24h", "top_clamped" => true} =
        json_response(conn, 200)
    end
  end
end
