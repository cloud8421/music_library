defmodule BraveSearch.APITest do
  use ExUnit.Case, async: true

  alias BraveSearch.API

  @config %BraveSearch.Config{
    api_key: "test_key",
    user_agent: "test_agent",
    req_options: [plug: {Req.Test, __MODULE__}, max_retries: 0],
    api_cooldown: 0
  }

  describe "search_images/3" do
    test "returns parsed results on success" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/res/v1/images/search"
        assert conn.params["q"] == "test query"

        body = %{
          "results" => [
            %{
              "thumbnail" => %{"src" => "https://example.com/thumb.jpg"},
              "properties" => %{
                "url" => "https://example.com/full.jpg",
                "width" => 800,
                "height" => 600
              },
              "title" => "Test Image",
              "source" => "example.com"
            }
          ]
        }

        Req.Test.json(conn, body)
      end)

      assert {:ok, [result]} = API.search_images("test query", [], @config)
      assert result.thumbnail_url == "https://example.com/thumb.jpg"
      assert result.image_url == "https://example.com/full.jpg"
      assert result.width == 800
      assert result.height == 600
      assert result.title == "Test Image"
      assert result.source == "example.com"
    end

    test "returns empty list when no results" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"results" => []})
      end)

      assert {:ok, []} = API.search_images("no results", [], @config)
    end

    @tag :capture_log
    test "returns error on non-200 response" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => "rate limited"})
      end)

      assert {:error, _} = API.search_images("test", [], @config)
    end

    test "passes count option as query param" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.params["count"] == "5"
        Req.Test.json(conn, %{"results" => []})
      end)

      assert {:ok, []} = API.search_images("test", [count: 5], @config)
    end
  end

  describe "download_image/2" do
    test "returns binary data on success" do
      image_data = <<0xFF, 0xD8, 0xFF, 0xE0>>

      Req.Test.stub(__MODULE__, fn conn ->
        Plug.Conn.send_resp(conn, 200, image_data)
      end)

      assert {:ok, ^image_data} = API.download_image("http://localhost/image.jpg", @config)
    end

    @tag :capture_log
    test "returns error on failure" do
      Req.Test.stub(__MODULE__, fn conn ->
        Plug.Conn.send_resp(conn, 404, "not found")
      end)

      assert {:error, :download_failed} =
               API.download_image("http://localhost/missing.jpg", @config)
    end
  end
end
