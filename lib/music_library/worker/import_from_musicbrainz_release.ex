defmodule MusicLibrary.Worker.ImportFromMusicbrainzRelease do
  @moduledoc """
  Imports a record from a MusicBrainz release in the background.

  Used by barcode scan batch imports when there are multiple new records to import.
  """

  use Oban.Worker, queue: :music_brainz, max_attempts: 3

  alias MusicLibrary.Records
  alias MusicLibrary.Records.Record
  alias MusicLibrary.Worker.ErrorHandler

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"release_id" => release_id} = args}) do
    opts = [
      format: args["format"],
      purchased_at: Record.parse_datetime(args["purchased_at"]),
      selected_release_id: args["selected_release_id"]
    ]

    case MusicLibrary.Records.import_from_musicbrainz_release(release_id, opts) do
      {:ok, _record} ->
        Records.broadcast_index_changed()
        :ok

      other ->
        ErrorHandler.to_oban_result(other)
    end
  end
end
