defmodule MusicLibraryWeb.LastFmController do
  use MusicLibraryWeb, :controller

  def callback(conn, %{"token" => token}) do
    case LastFm.get_session(token) do
      {:ok, session} ->
        conn
        |> put_session(:last_fm_user, session.name)
        |> put_session(:last_fm_key, session.key)
        |> put_flash(:info, "Successfully authenticated with Last.fm.")
        |> redirect(to: ~p"/")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to authenticate with Last.fm: #{reason}")
        |> redirect(to: ~p"/")
    end
  end
end
