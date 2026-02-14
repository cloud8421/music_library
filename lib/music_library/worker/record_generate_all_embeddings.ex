defmodule MusicLibrary.Worker.RecordGenerateAllEmbeddings do
  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  alias MusicLibrary.Records

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Records.Batch.generate_embeddings()
  end
end
