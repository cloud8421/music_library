defmodule MusicLibrary.Worker.RefreshCover do
  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => record_id}}) do
    record = MusicLibrary.Records.get_record!(record_id)

    case MusicLibrary.Records.refresh_cover(record) do
      {:ok, updated_record} ->
        MusicLibrary.Records.notify_update(updated_record)

      {:error, :cover_not_available} ->
        {:cancel, :cover_not_available}

      error ->
        error
    end
  end
end
