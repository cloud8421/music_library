defmodule MusicLibrary.Colors.KMeansExtractor do
  @moduledoc """
  Extracts dominant colors from images using K-Means clustering via the dominant_colors library.
  """

  alias Vix.Vips.Image

  @spec extract_dominant_colors(binary(), pos_integer()) :: {:ok, [String.t()]} | {:error, term()}
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
