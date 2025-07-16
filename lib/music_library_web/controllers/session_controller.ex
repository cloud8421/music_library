defmodule MusicLibraryWeb.SessionController do
  use MusicLibraryWeb, :controller

  alias MusicLibraryWeb.Auth

  @empty_form %{"password" => ""}

  def new(conn, _params) do
    conn
    |> delete_session(:logged_in)
    |> render(:new,
      page_title: gettext("Login"),
      form: @empty_form,
      layout: {MusicLibraryWeb.Layouts, "unauthenticated"}
    )
  end

  def create(conn, %{"password" => request_password}) do
    if Auth.correct_login_password?(request_password) do
      conn
      |> put_session(:logged_in, true)
      |> redirect(to: ~p"/")
    else
      conn
      |> put_toast(:error, gettext("Invalid password"))
      |> redirect(to: ~p"/login")
    end
  end
end
