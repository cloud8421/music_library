defmodule MusicLibrary.Worker.ImportFromMusicbrainzReleaseGroup do
  @moduledoc """
  Imports a record from a MusicBrainz release group in the background.

  Used by the cart-style multi-record import when there are two or more
  records to import at once.
  """

  use Oban.Worker,
    queue: :music_brainz,
    max_attempts: 3,
    unique: [period: 300, keys: [:release_group_id, :format]]

  alias MusicLibrary.Records
  alias MusicLibrary.Records.Record
  alias MusicLibrary.Worker.ErrorHandler

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"release_group_id" => release_group_id} = args}) do
    opts = [
      format: args["format"],
      purchased_at: Record.parse_datetime(args["purchased_at"])
    ]

    case Records.import_from_musicbrainz_release_group(release_group_id, opts) do
      {:ok, _record} -> :ok
      other -> ErrorHandler.to_oban_result(other)
    end
  end
end
