defmodule MusicLibrary.Worker.ExtractColors do
  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  alias MusicLibrary.{Colors, Records}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => record_id, "method" => method}}) do
    record = MusicLibrary.Records.get_record!(record_id)
    method = String.to_existing_atom(method)

    with {:ok, colors} <- Colors.extract_colors(record.cover_data, method),
         {:ok, updated_record} <- Records.update_record(record, %{dominant_colors: colors}) do
      MusicLibrary.Records.notify_update(updated_record)
    end
  end
end
