defmodule MusicLibrary.Worker.FetchArtistInfo do
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_id}}) do
    with {:ok, _artist_info} <- MusicLibrary.Artists.fetch_artist_info(artist_id) do
      :ok
    end
  end
end
