defmodule MusicLibrary.Worker.ImportFromMusicbrainzReleaseGroup do
  @moduledoc """
  Imports a record from a MusicBrainz release group in the background.

  Used by the cart-style multi-record import when there are two or more
  records to import at once.
  """

  use Oban.Worker, queue: :music_brainz, max_attempts: 3

  alias MusicLibrary.Records

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"release_group_id" => release_group_id} = args}) do
    opts = [
      format: args["format"],
      purchased_at: parse_datetime(args["purchased_at"])
    ]

    case Records.import_from_musicbrainz_release_group(release_group_id, opts) do
      {:ok, _record} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) do
    {:ok, datetime, _offset} = DateTime.from_iso8601(str)
    datetime
  end
end
