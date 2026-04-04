defmodule MusicLibrary.Worker.GenerateRecordEmbedding do
  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  alias MusicLibrary.Records
  alias MusicLibrary.Records.Similarity

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"record_id" => record_id}}) do
    record = Records.get_record!(record_id)

    case Similarity.generate_embedding(record) do
      :noop -> :ok
      {:ok, _} -> Records.notify_update(record)
      {:error, _} = error -> error
    end
  end
end
