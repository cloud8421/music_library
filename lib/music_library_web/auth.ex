defmodule MusicLibraryWeb.Auth do
  use Gettext, backend: MusicLibraryWeb.Gettext

  import LiveToast, only: [put_toast: 3]
  import Phoenix.Controller, only: [redirect: 2]
  import Plug.Conn

  def correct_login_password?(password) do
    Plug.Crypto.secure_compare(login_password(), password)
  end

  def require_api_token(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         true <- Plug.Crypto.secure_compare(api_token(), token) do
      conn
    else
      _ ->
        conn
        |> send_resp(:unauthorized, "Unauthorized API access")
        |> halt()
    end
  end

  defp login_password do
    Application.get_env(:music_library, MusicLibraryWeb)
    |> Keyword.fetch!(:login_password)
  end

  defp api_token do
    Application.get_env(:music_library, MusicLibraryWeb)
    |> Keyword.fetch!(:api_token)
  end

  def require_logged_in(conn, _opts) do
    if get_session(conn, :logged_in) do
      conn
    else
      conn
      |> put_toast(:error, gettext("You must be logged in to access this page"))
      |> redirect(to: "/login")
      |> halt()
    end
  end
end
