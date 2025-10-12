defmodule MusicLibrary.Worker.PopulateGenres do
  use Oban.Worker, queue: :heavy_writes, max_attempts: 10

  alias MusicLibrary.Records

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => record_id}}) do
    record = Records.get_record!(record_id)

    with {:ok, updated_record} <- Records.populate_genres(record),
         {:ok, _worker} <-
           Records.Similarity.generate_embedding_async(updated_record) do
      Records.notify_update(updated_record)
    end
  end
end
