defmodule MusicLibraryWeb.HealthControllerTest do
  use MusicLibraryWeb.ConnCase

  describe "GET /health" do
    @tag :logged_out
    test "returns 200 with health message", %{conn: conn} do
      conn = get(conn, "/health")

      assert html_response(conn, 200) =~ "App is running"
    end
  end
end
