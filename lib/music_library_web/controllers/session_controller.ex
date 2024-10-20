defmodule MusicLibraryWeb.SessionController do
  use MusicLibraryWeb, :controller

  @empty_form %{"password" => ""}

  def new(conn, _params) do
    conn |> render(:new, form: @empty_form, layout: {MusicLibraryWeb.Layouts, "unauthenticated"})
  end

  def create(conn, params) do
    password = params["password"]

    if password == "password" do
      conn
      |> put_session(:logged_in, true)
      |> redirect(to: "/")
    else
      conn
      |> put_flash(:error, "Invalid password")
      |> redirect(to: ~p"/login")
    end
  end
end
