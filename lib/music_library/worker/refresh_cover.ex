defmodule MusicLibrary.Worker.RefreshCover do
  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => record_id}}) do
    record = MusicLibrary.Records.get_record!(record_id)
    {:ok, _} = MusicLibrary.Records.refresh_cover(record)
    :ok
  end
end
