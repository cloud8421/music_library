defmodule MusicLibrary.Worker.GenerateRecordEmbedding do
  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  alias MusicLibrary.Records
  alias MusicLibrary.Records.Similarity

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"record_id" => record_id}}) do
    record = Records.get_record!(record_id)

    with {:ok, embedding} <- generate_embedding(record),
         {:ok, _} <- store_embedding(record, embedding) do
      Records.notify_update(record)
    end
  end

  defp generate_embedding(record) do
    text = Similarity.text_representation(record)

    case OpenAI.embeddings(text) do
      {:ok, embedding} ->
        {:ok, {embedding, text}}

      error ->
        error
    end
  end

  defp store_embedding(record, {embedding, text_representation}) do
    Similarity.store_embedding(record.id, embedding, text_representation)
  end
end
