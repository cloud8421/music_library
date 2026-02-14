defmodule MusicLibrary.Worker.ArtistRefreshAllWikipediaData do
  use Oban.Worker, queue: :wikipedia, max_attempts: 3

  alias MusicLibrary.Artists

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Artists.Batch.refresh_wikipedia_data()
  end
end
