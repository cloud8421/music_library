defmodule MusicLibrary.Worker.ArtistRefreshWikipediaData do
  use Oban.Worker, queue: :wikipedia, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_info_id}}) do
    result = MusicLibrary.Artists.refresh_wikipedia_data(artist_info_id)

    Process.sleep(1_000)

    result
  end
end
