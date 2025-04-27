defmodule MusicLibrary.Worker.RefreshCover do
  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => record_id}}) do
    record = MusicLibrary.Records.get_record!(record_id)

    with {:ok, updated_record} <- MusicLibrary.Records.refresh_cover(record) do
      MusicLibrary.Records.notify_update(updated_record)
    end
  end
end
