defmodule MusicLibrary.Worker.PopulateGenres do
  @moduledoc false

  use Oban.Worker, queue: :openai, max_attempts: 10

  alias MusicLibrary.Records
  alias MusicLibrary.Worker.ErrorHandler

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => record_id}}) do
    record = Records.get_record!(record_id)

    with {:ok, updated_record} <- Records.populate_genres(record),
         {:ok, _worker} <- Records.Similarity.generate_embedding_async(updated_record) do
      Records.notify_update(updated_record)
    else
      other -> ErrorHandler.to_oban_result(other)
    end
  end
end
