defmodule MusicLibraryWeb.LastFmController do
  @moduledoc """
  Handles the Last.fm OAuth callback.

  ## Trust boundary

  `GET /auth/last_fm/callback` is deliberately outside the `:logged_in`
  pipeline: Last.fm redirects the browser back to us with a `token` query
  parameter, and that third-party redirect cannot carry our session cookie,
  so requiring a logged-in session here would break the OAuth flow.

  What protects the endpoint:

    * The `token` is validated by Last.fm via `LastFm.get_session/1`
      against the `LAST_FM_API_KEY` / `LAST_FM_SHARED_SECRET` pair — it
      cannot be forged locally.
    * The Last.fm HTTP client is rate-limited at the `Req` layer
      (`Req.RateLimiter`, 500ms between requests), bounding the quota a
      malicious caller could burn.
    * This is a single-user deployment; the stored session key grants
      scrobble access for one account, not multi-tenant credentials.

  Failure mode: an invalid or forged `token` makes `get_session/1` return
  `{:error, reason}`; nothing is written to the `secrets` table, the user
  sees an error toast, and the upstream error is logged by the Req layer.
  """

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
