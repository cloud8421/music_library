defmodule MusicLibraryWeb.CoverControllerTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.RecordsFixtures
  alias MusicLibrary.Records.Cover

  defp create_record(_) do
    %{record: record_fixture()}
  end

  describe "GET /covers/:record_id" do
    setup [:create_record]

    test "404s when record doesn't exist", %{conn: conn} do
      id = Ecto.UUID.generate()

      conn = get(conn, ~p"/covers/#{id}")
      assert text_response(conn, 404) == "Not found"
    end

    test "serves the cover without etag", %{conn: conn, record: record} do
      conn = get(conn, ~p"/covers/#{record.id}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=86400"]
      assert get_resp_header(conn, "etag") == [record.cover_hash]

      assert conn.resp_body == record.cover_data
    end

    test "serves the cover when etag doesn't match", %{conn: conn, record: record} do
      conn =
        conn
        |> put_req_header("if-none-match", "invalid-etag")
        |> get(~p"/covers/#{record.id}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=86400"]
      assert get_resp_header(conn, "etag") == [record.cover_hash]

      assert conn.resp_body == record.cover_data
    end

    test "serves a 304 when etag matches", %{conn: conn, record: record} do
      conn =
        conn
        |> put_req_header("if-none-match", record.cover_hash)
        |> get(~p"/covers/#{record.id}")

      assert conn.status == 304
      assert get_resp_header(conn, "content-type") == []
      assert get_resp_header(conn, "cache-control") == ["public, max-age=86400"]
      assert get_resp_header(conn, "etag") == []

      assert conn.resp_body == <<>>
    end

    test "accepts a size attribute for resizing", %{conn: conn, record: record} do
      conn = get(conn, ~p"/covers/#{record.id}?size=480")

      thumb = File.read!(marbles_thumb_fixture())
      hash = Cover.hash(thumb)

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=86400"]
      assert get_resp_header(conn, "etag") == [hash]

      assert conn.resp_body == thumb
    end
  end
end
