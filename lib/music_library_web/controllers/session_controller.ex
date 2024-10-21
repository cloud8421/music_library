defmodule MusicLibraryWeb.SessionController do
  use MusicLibraryWeb, :controller

  @empty_form %{"password" => ""}

  def new(conn, _params) do
    conn
    |> delete_session(:logged_in)
    |> render(:new, form: @empty_form, layout: {MusicLibraryWeb.Layouts, "unauthenticated"})
  end

  def create(conn, %{"password" => request_password}) do
    if Plug.Crypto.secure_compare(password(), request_password) do
      conn
      |> put_session(:logged_in, true)
      |> redirect(to: "/")
    else
      conn
      |> put_flash(:error, "Invalid password")
      |> redirect(to: ~p"/login")
    end
  end

  def password do
    Application.get_env(:music_library, MusicLibraryWeb)
    |> Keyword.fetch!(:auth_password)
  end
end
