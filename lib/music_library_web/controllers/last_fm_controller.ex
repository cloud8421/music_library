defmodule MusicLibraryWeb.LastFmController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Secrets
  alias MusicLibraryWeb.ErrorMessages

  def callback(conn, %{"token" => token}) do
    with {:ok, session} <- LastFm.get_session(token),
         {:ok, _secret} <- Secrets.store("last_fm_session_key", session.key) do
      conn
      |> put_toast(:info, gettext("Successfully connected your Last.fm account"))
      |> redirect(to: ~p"/")
    else
      {:error, reason} ->
        conn
        |> put_toast(
          :error,
          gettext("Failed to connect your Last.fm account") <>
            ": " <> ErrorMessages.friendly_message(reason)
        )
        |> redirect(to: ~p"/")
    end
  end
end
