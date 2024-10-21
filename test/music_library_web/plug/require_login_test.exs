defmodule MusicLibraryWeb.Plug.RequireLoginTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias MusicLibraryWeb.Plug.RequireLogin

  defp setup_conn(config) do
    Map.put(
      config,
      :conn,
      conn(:get, "/any-path")
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Phoenix.ConnTest.fetch_flash()
    )
  end

  defp authenticate(%{conn: conn} = config) do
    Map.put(config, :conn, Phoenix.ConnTest.init_test_session(conn, %{logged_in: true}))
  end

  describe "when logged out" do
    setup [:setup_conn]

    test "it redirects to /login", %{conn: conn} do
      conn = RequireLogin.call(conn, [])

      {"location", location} =
        conn.resp_headers
        |> List.keyfind("location", 0)

      assert conn.status == 302
      assert conn.state == :sent
      assert conn.halted
      assert location == "/login"
      assert conn.assigns.flash == %{"error" => "You must be logged in to access this page"}
    end
  end

  describe "when logged in" do
    setup [:setup_conn, :authenticate]

    test "it passes through", %{conn: conn} do
      conn = RequireLogin.call(conn, [])

      assert conn.status == nil
      assert conn.state == :unset
    end
  end
end
