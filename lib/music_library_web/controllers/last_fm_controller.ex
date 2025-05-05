defmodule MusicLibraryWeb.LastFmController do
  use MusicLibraryWeb, :controller

  def callback(conn, %{"token" => _token}) do
    conn |> redirect(to: ~p"/")
  end
end
