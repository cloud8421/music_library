defmodule MusicLibraryWeb.Plug.RequireLogin do
  @behaviour Plug

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
      |> put_flash(:error, "You must be logged in to access this page")
      |> redirect(to: "/login")
      |> halt()
    end
  end
end
