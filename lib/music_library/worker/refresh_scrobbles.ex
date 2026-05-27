defmodule MusicLibrary.Worker.RefreshScrobbles do
  @moduledoc """
  Fetches recent scrobbled tracks from Last.fm and persists them.

  Scheduled via Oban Cron and can be triggered manually via
  `MusicLibrary.ListeningStats.refresh/0`.
  """

  use Oban.Worker,
    queue: :last_fm,
    max_attempts: 3,
    unique: [period: 60, states: :incomplete]

  alias LastFm.{API, Config}
  alias MusicLibrary.ListeningStats

  @impl Oban.Worker
  def perform(_job) do
    api_config = Config.resolve(:music_library)

    case API.get_recent_tracks(api_config) do
      {:ok, tracks} ->
        ListeningStats.update(tracks)
        :ok

      {:error, %API.ErrorResponse{error: error} = resp} ->
        if API.ErrorResponse.retryable_error?(error) do
          seconds = error |> API.ErrorResponse.retry_delay() |> div(1000)
          {:snooze, seconds}
        else
          {:cancel, resp}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
