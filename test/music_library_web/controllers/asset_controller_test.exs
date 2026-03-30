defmodule MusicLibraryWeb.AssetControllerTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Assets
  alias MusicLibrary.Assets.Transform

  defp create_asset(_config) do
    {:ok, asset} = Assets.store(%{content: marbles_cover_data(), format: "image/jpeg"})

    %{asset: asset}
  end

  describe "GET /assets/:payload" do
    setup [:create_asset]

    test "404s when asset doesn't exist", %{conn: conn} do
      transform = %Transform{hash: Ecto.UUID.generate()}
      payload = Transform.encode!(transform)

      conn = get(conn, ~p"/assets/#{payload}")
      assert text_response(conn, 404) == "Not found"
    end

    test "serves the asset when no etag is sent", %{conn: conn, asset: asset} do
      transform = %Transform{hash: asset.hash}
      payload = Transform.encode!(transform)
      conn = get(conn, ~p"/assets/#{payload}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000"]
      assert get_resp_header(conn, "etag") == [payload]

      assert conn.resp_body == asset.content
    end

    test "serves the asset when etag doesn't match", %{conn: conn, asset: asset} do
      transform = %Transform{hash: asset.hash}
      payload = Transform.encode!(transform)

      conn =
        conn
        |> put_req_header("if-none-match", "invalid-etag")
        |> get(~p"/assets/#{payload}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000"]
      assert get_resp_header(conn, "etag") == [payload]

      assert conn.resp_body == asset.content
    end

    test "serves a 304 when etag matches", %{conn: conn, asset: asset} do
      transform = %Transform{hash: asset.hash}
      payload = Transform.encode!(transform)

      conn =
        conn
        |> put_req_header("if-none-match", payload)
        |> get(~p"/assets/#{payload}")

      assert conn.status == 304
      assert get_resp_header(conn, "content-type") == []
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000"]
      assert get_resp_header(conn, "etag") == []

      assert conn.resp_body == <<>>
    end

    test "400s on invalid base64 payload", %{conn: conn} do
      conn = get(conn, ~p"/assets/!!!invalid-base64!!!")
      assert text_response(conn, 400) == "Bad request"
    end

    test "400s on valid base64 but invalid JSON payload", %{conn: conn} do
      payload = Base.url_encode64("not json", padding: false)
      conn = get(conn, ~p"/assets/#{payload}")
      assert text_response(conn, 400) == "Bad request"
    end

    test "404s when payload has null hash", %{conn: conn} do
      payload = Base.url_encode64(JSON.encode!(%{hash: nil, width: nil}), padding: false)
      conn = get(conn, ~p"/assets/#{payload}")
      assert text_response(conn, 404) == "Not found"
    end

    @tag :capture_log
    test "404s when asset content is corrupt", %{conn: conn} do
      {:ok, asset} = Assets.store(%{content: "not an image", format: "image/jpeg"})
      transform = %Transform{hash: asset.hash, width: 480}
      payload = Transform.encode!(transform)

      conn = get(conn, ~p"/assets/#{payload}")
      assert text_response(conn, 404) == "Not found"
    end

    test "handles transforms with width", %{conn: conn, asset: asset} do
      transform = %Transform{hash: asset.hash, width: 480}
      payload = Transform.encode!(transform)

      conn = get(conn, ~p"/assets/#{payload}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000"]
      assert get_resp_header(conn, "etag") == [payload]

      assert conn.resp_body == marbles_thumb_data()
    end
  end
end
