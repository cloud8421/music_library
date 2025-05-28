defmodule MusicLibraryWeb.AuthTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias MusicLibraryWeb.Auth

  defp setup_conn(_config) do
    conn =
      conn(:get, "/any-path")
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Phoenix.ConnTest.fetch_flash()

    %{conn: conn}
  end

  describe "require_logged_in/2" do
    setup [:setup_conn]

    test "when logged out, it redirects to /login", %{conn: conn} do
      conn = Auth.require_logged_in(conn, [])

      {"location", location} =
        conn.resp_headers
        |> List.keyfind("location", 0)

      assert conn.status == 302
      assert conn.state == :sent
      assert conn.halted
      assert location == "/login"
      assert conn.assigns.flash == %{"error" => "You must be logged in to access this page"}
    end

    test "when logged in, it passes through", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{logged_in: true})
        |> Auth.require_logged_in([])

      assert conn.status == nil
      assert conn.state == :unset
    end
  end
end
