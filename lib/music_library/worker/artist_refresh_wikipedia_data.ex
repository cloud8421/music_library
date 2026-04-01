defmodule MusicLibrary.Worker.ArtistRefreshWikipediaData do
  use Oban.Worker, queue: :wikipedia, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_info_id}}) do
    with {:error, :no_english_wikipedia} <-
           MusicLibrary.Artists.refresh_wikipedia_data(artist_info_id) do
      {:cancel, :no_english_wikipedia}
    end
  end
end
