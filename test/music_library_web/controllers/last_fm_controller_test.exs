defmodule MusicLibraryWeb.LastFmControllerTest do
  use MusicLibraryWeb.ConnCase

  describe "GET /auth/last_fm/callback" do
    @tag :logged_out
    test "on success, stores session key and redirects with flash", %{conn: conn} do
      session_xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <lfm status="ok">
        <session>
          <name>testuser</name>
          <key>test-session-key</key>
          <subscriber>0</subscriber>
        </session>
      </lfm>
      """

      Req.Test.stub(LastFm.API, fn conn ->
        Req.Test.text(conn, session_xml)
      end)

      conn = get(conn, ~p"/auth/last_fm/callback", %{"token" => "test-token"})

      assert redirected_to(conn) == "/"
      assert conn.assigns.flash["info"] =~ "Successfully connected"
    end

    @tag :logged_out
    @tag :capture_log
    test "on error, redirects with error flash", %{conn: conn} do
      error_json = %{
        "error" => 4,
        "message" => "Invalid authentication token"
      }

      Req.Test.stub(LastFm.API, fn conn ->
        Req.Test.json(conn, error_json)
      end)

      conn = get(conn, ~p"/auth/last_fm/callback", %{"token" => "bad-token"})

      assert redirected_to(conn) == "/"
      assert conn.assigns.flash["error"] =~ "Failed to connect"
    end
  end
end
