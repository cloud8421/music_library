defmodule MusicLibrary.Worker.ArtistRefreshDiscogsData do
  use Oban.Worker, queue: :discogs, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_info_id}}) do
    MusicLibrary.Artists.refresh_discogs_data(artist_info_id)

    Process.sleep(100)
  end
end
