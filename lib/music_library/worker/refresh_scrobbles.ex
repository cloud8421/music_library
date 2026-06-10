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
  alias MusicLibrary.Worker.ErrorHandler

  @impl Oban.Worker
  def perform(_job) do
    api_config = Config.resolve(:music_library)

    case API.get_recent_tracks(api_config) do
      {:ok, tracks} ->
        ListeningStats.update(tracks)
        :ok

      {:error, error_atom} when is_atom(error_atom) ->
        # Last.fm API returns atoms for application-level errors.
        # Wrap in ErrorResponse for uniform handling through ErrorHandler.
        error = %API.ErrorResponse{error: error_atom}
        ErrorHandler.to_oban_result({:error, error})

      {:error, reason} ->
        {:error, reason}
    end
  end
end
