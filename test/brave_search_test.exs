defmodule BraveSearchTest do
  use ExUnit.Case, async: true

  describe "search_images/2" do
    test "normalizes results, preserving nil for missing nested fields" do
      Req.Test.stub(BraveSearch.API, fn conn ->
        Req.Test.json(conn, BraveSearch.Fixtures.search_images_response())
      end)

      assert {:ok, results} = BraveSearch.search_images("steven wilson")

      assert results == [
               %{
                 thumbnail_url: "https://thumbnails.example.com/raven-thumb.jpg",
                 image_url: "https://images.example.com/raven-cover.jpg",
                 width: 1200,
                 height: 1200,
                 title: "The Raven That Refused To Sing - Cover",
                 source: "https://example.com/page/raven"
               },
               %{
                 thumbnail_url: nil,
                 image_url: "https://images.example.com/hce-cover.jpg",
                 width: 800,
                 height: 800,
                 title: "Hand. Cannot. Erase. - Alternate Cover",
                 source: "https://example.com/page/hce"
               },
               %{
                 thumbnail_url: "https://thumbnails.example.com/ttb-thumb.jpg",
                 image_url: nil,
                 width: nil,
                 height: nil,
                 title: "To The Bone - Promo Shot",
                 source: "https://example.com/page/ttb"
               },
               %{
                 thumbnail_url: "https://thumbnails.example.com/unknown-thumb.jpg",
                 image_url: "https://images.example.com/unknown.jpg",
                 width: 640,
                 height: 480,
                 title: "",
                 source: ""
               }
             ]
    end

    test "forwards the query and explicit count as request params" do
      Req.Test.stub(BraveSearch.API, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.request_path == "/res/v1/images/search"
        assert conn.query_params["q"] == "porcupine tree"
        assert conn.query_params["count"] == "5"
        Req.Test.json(conn, %{"results" => []})
      end)

      assert {:ok, []} = BraveSearch.search_images("porcupine tree", count: 5)
    end

    test "defaults count to 20 when not supplied" do
      Req.Test.stub(BraveSearch.API, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["count"] == "20"
        Req.Test.json(conn, %{"results" => []})
      end)

      assert {:ok, []} = BraveSearch.search_images("marillion")
    end

    test "returns an empty list when the response has no results key" do
      Req.Test.stub(BraveSearch.API, fn conn ->
        Req.Test.json(conn, %{})
      end)

      assert {:ok, []} = BraveSearch.search_images("nothing")
    end

    @tag :capture_log
    test "returns an ErrorResponse struct on non-200 responses" do
      Req.Test.stub(BraveSearch.API, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, ~s({"error":"rate_limited"}))
      end)

      assert {:error, %BraveSearch.API.ErrorResponse{status: 429, kind: :rate_limit}} =
               BraveSearch.search_images("too many requests")
    end
  end

  describe "download_image/1" do
    @jpeg_magic <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10>>

    test "returns the raw image binary on a 200 response" do
      Req.Test.stub(BraveSearch.API, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("image/jpeg")
        |> Plug.Conn.send_resp(200, @jpeg_magic)
      end)

      assert {:ok, @jpeg_magic} =
               BraveSearch.download_image("https://images.example.com/raven-cover.jpg")
    end

    @tag :capture_log
    test "returns :download_failed on non-200 responses" do
      Req.Test.stub(BraveSearch.API, fn conn ->
        Plug.Conn.send_resp(conn, 404, "")
      end)

      assert {:error, :download_failed} =
               BraveSearch.download_image("https://images.example.com/missing.jpg")
    end

    test "returns :download_failed on transport errors" do
      Req.Test.stub(BraveSearch.API, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, :download_failed} =
               BraveSearch.download_image("https://images.example.com/slow.jpg")
    end
  end
end
