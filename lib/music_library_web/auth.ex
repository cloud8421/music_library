defmodule MusicLibraryWeb.Auth do
  use Gettext, backend: MusicLibraryWeb.Gettext
  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  def correct_login_password?(password) do
    Plug.Crypto.secure_compare(correct_login_password(), password)
  end

  defp correct_login_password do
    Application.get_env(:music_library, MusicLibraryWeb)
    |> Keyword.fetch!(:login_password)
  end

  def require_logged_in(conn, _opts) do
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
