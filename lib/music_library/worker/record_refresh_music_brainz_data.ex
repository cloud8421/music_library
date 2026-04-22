defmodule MusicLibrary.Worker.RecordRefreshMusicBrainzData do
  use Oban.Worker, queue: :music_brainz, max_attempts: 3

  alias MusicLibrary.Records

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => record_id}}) do
    record = Records.get_record!(record_id)

    with {:ok, updated_record} <- Records.refresh_musicbrainz_data(record) do
      Records.notify_update(updated_record)
    end
  end
end
