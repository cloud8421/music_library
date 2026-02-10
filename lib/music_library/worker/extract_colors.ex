defmodule MusicLibrary.Worker.ExtractColors do
  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  alias MusicLibrary.{Assets, Records}
  alias MusicLibrary.Colors.{ColorFrequencyExtractor, EdgeWeightedExtractor}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => record_id, "method" => method}}) do
    record = MusicLibrary.Records.get_record!(record_id)
    asset = Assets.get!(record.cover_hash)
    method = String.to_existing_atom(method)

    with {:ok, colors} <- extract_colors(asset.content, method),
         {:ok, updated_record} <- Records.update_record(record, %{dominant_colors: colors}) do
      MusicLibrary.Records.notify_update(updated_record)
    end
  end

  defp extract_colors(image_data, :fast),
    do: ColorFrequencyExtractor.extract_dominant_colors(image_data)

  defp extract_colors(image_data, :slow),
    do: EdgeWeightedExtractor.extract_dominant_colors(image_data)
end
