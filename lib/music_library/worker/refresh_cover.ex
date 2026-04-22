defmodule MusicLibrary.Worker.RefreshCover do
  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  alias MusicLibrary.Records

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => record_id}}) do
    record = Records.get_record!(record_id)

    case Records.refresh_cover(record) do
      {:ok, updated_record} ->
        Records.notify_update(updated_record)

      {:error, :cover_not_available} ->
        {:cancel, :cover_not_available}

      error ->
        error
    end
  end
end
