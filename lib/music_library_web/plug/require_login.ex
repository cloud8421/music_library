defmodule MusicLibraryWeb.Plug.RequireLogin do
  @behaviour Plug

  use Gettext, backend: MusicLibraryWeb.Gettext
  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if get_session(conn, :logged_in) do
      conn
    else
      conn
      |> put_flash(:error, gettext("You must be logged in to access this page"))
      |> redirect(to: "/login")
      |> halt()
    end
  end
end
