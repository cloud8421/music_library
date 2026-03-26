defmodule MusicLibrary.Colors.KMeansExtractor do
  @moduledoc """
  Extracts dominant colors from images using K-Means clustering via the dominant_colors library.
  """

  @behaviour MusicLibrary.Colors.Extractor

  alias Vix.Vips.Image

  @impl true
  def extract_dominant_colors(image_data, num_colors \\ 5) do
    :telemetry.span(
      [:music_library, :colors, :extract],
      %{},
      fn ->
        result =
          with {:ok, dir} <- Briefly.create(type: :directory),
               path = dir <> "/temp_image.jpg",
               {:ok, image} <- Image.new_from_buffer(image_data),
               :ok <- Image.write_to_file(image, path),
               {:ok, colors} <- DominantColors.dominant_colors(path) do
            {:ok, Enum.take(colors, num_colors)}
          end

        {result, %{}}
      end
    )
  end
end
