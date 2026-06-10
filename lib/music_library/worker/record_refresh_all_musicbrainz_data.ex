defmodule MusicLibrary.Worker.RecordRefreshAllMusicBrainzData do
  use Oban.Worker,
    queue: :music_brainz,
    max_attempts: 3,
    unique: [period: :infinity, states: :incomplete]

  alias MusicLibrary.Records

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Records.Batch.refresh_musicbrainz_data()
  end
end
