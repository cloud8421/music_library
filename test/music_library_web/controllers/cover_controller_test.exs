defmodule MusicLibraryWeb.CoverControllerTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Assets

  defp create_asset(_config) do
    {:ok, asset} = Assets.store(%{content: marbles_cover_data(), format: "image/jpeg"})

    %{asset: asset}
  end

  describe "GET /covers/:hash" do
    setup [:create_asset]

    test "404s when asset doesn't exist", %{conn: conn} do
      id = Ecto.UUID.generate()

      conn = get(conn, ~p"/covers/#{id}")
      assert text_response(conn, 404) == "Not found"
    end

    test "serves the cover without etag", %{conn: conn, asset: asset} do
      conn = get(conn, ~p"/covers/#{asset.hash}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000"]
      assert get_resp_header(conn, "etag") == [asset.hash]

      assert conn.resp_body == asset.content
    end

    test "serves the cover when etag doesn't match", %{conn: conn, asset: asset} do
      conn =
        conn
        |> put_req_header("if-none-match", "invalid-etag")
        |> get(~p"/covers/#{asset.hash}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000"]
      assert get_resp_header(conn, "etag") == [asset.hash]

      assert conn.resp_body == asset.content
    end

    test "serves a 304 when etag matches", %{conn: conn, asset: asset} do
      conn =
        conn
        |> put_req_header("if-none-match", asset.hash)
        |> get(~p"/covers/#{asset.hash}")

      assert conn.status == 304
      assert get_resp_header(conn, "content-type") == []
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000"]
      assert get_resp_header(conn, "etag") == []

      assert conn.resp_body == <<>>
    end

    test "accepts a size attribute for resizing", %{conn: conn, asset: asset} do
      conn = get(conn, ~p"/covers/#{asset.hash}?size=480")

      thumb = marbles_thumb_data()
      hash = Assets.Asset.hash(thumb)

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000"]
      assert get_resp_header(conn, "etag") == [hash]

      assert conn.resp_body == thumb
    end
  end
end
