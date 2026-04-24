defmodule MusicLibrary.Worker.FetchArtistLastFmData do
  @moduledoc false

  use Oban.Worker, queue: :last_fm, max_attempts: 3

  alias MusicLibrary.Worker.ErrorHandler

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_id}}) do
    case MusicLibrary.Artists.refresh_lastfm_data(artist_id) do
      {:ok, _artist_info} -> :ok
      other -> ErrorHandler.to_oban_result(other)
    end
  end
end
