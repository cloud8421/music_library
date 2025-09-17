defmodule MusicLibraryWeb.CoverControllerTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Assets
  alias MusicLibrary.Assets.Transform

  defp create_asset(_config) do
    {:ok, asset} = Assets.store(%{content: marbles_cover_data(), format: "image/jpeg"})

    %{asset: asset}
  end

  describe "GET /covers/:payload" do
    setup [:create_asset]

    test "404s when asset doesn't exist", %{conn: conn} do
      transform = %Transform{hash: Ecto.UUID.generate()}
      payload = Transform.encode!(transform)

      conn = get(conn, ~p"/covers/#{payload}")
      assert text_response(conn, 404) == "Not found"
    end

    test "serves the cover without etag", %{conn: conn, asset: asset} do
      transform = %Transform{hash: asset.hash}
      payload = Transform.encode!(transform)
      conn = get(conn, ~p"/covers/#{payload}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000"]
      assert get_resp_header(conn, "etag") == [payload]

      assert conn.resp_body == asset.content
    end

    test "serves the cover when etag doesn't match", %{conn: conn, asset: asset} do
      transform = %Transform{hash: asset.hash}
      payload = Transform.encode!(transform)

      conn =
        conn
        |> put_req_header("if-none-match", "invalid-etag")
        |> get(~p"/covers/#{payload}")

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
        |> get(~p"/covers/#{payload}")

      assert conn.status == 304
      assert get_resp_header(conn, "content-type") == []
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000"]
      assert get_resp_header(conn, "etag") == []

      assert conn.resp_body == <<>>
    end

    test "it handles transforms with width", %{conn: conn, asset: asset} do
      transform = %Transform{hash: asset.hash, width: 480}
      payload = Transform.encode!(transform)

      conn = get(conn, ~p"/covers/#{payload}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000"]
      assert get_resp_header(conn, "etag") == [payload]

      assert conn.resp_body == marbles_thumb_data()
    end
  end
end
