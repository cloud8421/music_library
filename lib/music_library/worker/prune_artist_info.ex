defmodule MusicLibrary.Worker.PruneArtistInfo do
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_id}}) do
    if MusicLibrary.Artists.exists?(artist_id) do
      :ok
    else
      delete_artist_info(artist_id)
    end
  end

  defp delete_artist_info(artist_id) do
    with {_count, nil} <- MusicLibrary.Artists.delete_artist_info(artist_id) do
      :ok
    end
  end
end
