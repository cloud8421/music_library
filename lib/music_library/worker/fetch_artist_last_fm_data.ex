defmodule MusicLibrary.Worker.FetchArtistLastFmData do
  use Oban.Worker, queue: :last_fm, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_id}}) do
    result =
      case MusicLibrary.Artists.fetch_lastfm_data(artist_id) do
        {:ok, _artist_info} -> :ok
        error -> error
      end

    Process.sleep(500)

    result
  end
end
