defmodule MusicLibraryWeb.Hooks.GetTimezoneTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest, only: [live: 2, put_connect_params: 2]

  describe "on_mount/4" do
    test "falls back to default_timezone when no connect param is provided", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/collection")
      socket = :sys.get_state(view.pid).socket

      assert socket.assigns.timezone == MusicLibrary.default_timezone()
    end

    test "assigns timezone from connect params when provided", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> put_connect_params(%{"timezone" => "America/New_York"})
        |> live(~p"/collection")

      socket = :sys.get_state(view.pid).socket

      assert socket.assigns.timezone == "America/New_York"
    end
  end
end
