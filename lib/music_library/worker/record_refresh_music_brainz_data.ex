defmodule MusicLibrary.Worker.RecordRefreshMusicBrainzData do
  @moduledoc false

  use Oban.Worker, queue: :music_brainz, max_attempts: 3

  alias MusicLibrary.Records
  alias MusicLibrary.Worker.ErrorHandler

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => record_id}}) do
    record = Records.get_record!(record_id)

    case Records.refresh_musicbrainz_data(record) do
      {:ok, updated_record} -> Records.notify_update(updated_record)
      other -> ErrorHandler.to_oban_result(other)
    end
  end
end
