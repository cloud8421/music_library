defmodule MusicLibrary.Worker.ArtistRefreshMusicBrainzData do
  use Oban.Worker, queue: :music_brainz, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_info_id}}) do
    MusicLibrary.Artists.refresh_musicbrainz_data(artist_info_id)
  end
end
