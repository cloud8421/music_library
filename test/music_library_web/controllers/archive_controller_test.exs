defmodule MusicLibraryWeb.ArchiveControllerTest do
  use MusicLibraryWeb.ConnCase

  describe "GET /backup" do
    test "returns a sqlite database file", %{conn: conn} do
      conn = get(conn, "/backup")

      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/x-sqlite3"

      [content_disposition] = get_resp_header(conn, "content-disposition")
      assert content_disposition =~ "attachment"
      assert content_disposition =~ "music_library_"
      assert content_disposition =~ ".db"
    end
  end
end
