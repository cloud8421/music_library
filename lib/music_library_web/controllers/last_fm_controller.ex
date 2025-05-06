defmodule MusicLibraryWeb.LastFmController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Secrets

  def callback(conn, %{"token" => token}) do
    with {:ok, session} <- LastFm.get_session(token),
         {:ok, _secret} <- Secrets.store("last_fm_key", session.key) do
      conn
      |> put_flash(:info, gettext("Successfully connected your Last.fm account"))
      |> redirect(to: ~p"/")
    else
      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to connect your Last.fm account: #{reason}")
        |> redirect(to: ~p"/")
    end
  end
end
