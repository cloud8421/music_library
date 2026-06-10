defmodule MusicLibrary.Worker.ArtistRefreshAllDiscogsData do
  use Oban.Worker,
    queue: :discogs,
    max_attempts: 3,
    unique: [period: :infinity, states: :incomplete]

  alias MusicLibrary.Artists

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Artists.Batch.refresh_discogs_data()
  end
end
