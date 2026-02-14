defmodule MusicLibrary.Worker.ArtistRefreshAllMusicBrainzData do
  use Oban.Worker, queue: :music_brainz, max_attempts: 3

  alias MusicLibrary.Artists

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Artists.Batch.refresh_musicbrainz_data()
  end
end
