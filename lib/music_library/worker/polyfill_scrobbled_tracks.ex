defmodule MusicLibrary.Worker.PolyfillScrobbledTracks do
  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  alias MusicLibrary.ScrobbleActivity.Backfill

  @impl Oban.Worker
  def perform(%Oban.Job{args: _}) do
    Backfill.fill_missing_artist_ids()
  end
end
