defmodule MusicLibraryWeb.Hooks.StaticAssetsTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest, only: [live: 2]

  describe "on_mount/4" do
    test "assigns :static_changed to a boolean", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/collection")
      socket = :sys.get_state(view.pid).socket

      assert is_boolean(socket.assigns.static_changed)
    end
  end
end
