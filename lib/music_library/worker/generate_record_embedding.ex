defmodule MusicLibrary.Worker.GenerateRecordEmbedding do
  @moduledoc false

  use Oban.Worker, queue: :openai, max_attempts: 3

  alias MusicLibrary.Records
  alias MusicLibrary.Records.Similarity
  alias MusicLibrary.Worker.ErrorHandler

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"record_id" => record_id}}) do
    record = Records.get_record!(record_id)

    case Similarity.generate_embedding(record) do
      :noop -> :ok
      {:ok, _} -> Records.notify_update(record)
      other -> ErrorHandler.to_oban_result(other)
    end
  end
end
