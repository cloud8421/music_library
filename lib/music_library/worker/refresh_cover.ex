defmodule MusicLibrary.Worker.RefreshCover do
  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => record_id}}) do
    record = MusicLibrary.Records.get_record!(record_id)
    {:ok, new_record} = MusicLibrary.Records.refresh_cover(record)
    MusicLibrary.Records.notify_update(new_record)
    :ok
  end
end
