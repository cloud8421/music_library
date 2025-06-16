defmodule MusicLibrary.Colors.ColorFrequencyExtractor do
  @moduledoc """
  Extracts dominant colors from images using Vix.

  Uses a fast but naive approach based on color sampling and histogram
  analysis.

  Initially by Claude, using Sonnet 4.
  """

  alias Vix.Vips.{Image, Operation}

  @doc """
  Extracts the n most dominant colors from image data (defaults to 5)
  and returns them in hex format, e.g. ["#FF5733", "#33C3FF", "#75FF33"].
  """
  @spec extract_dominant_colors(binary(), pos_integer()) :: {:ok, [String.t()]} | {:error, term()}
  def extract_dominant_colors(image_data, num_colors \\ 5) do
    with {:ok, image} <- Image.new_from_buffer(image_data),
         {:ok, processed_image} <- prepare_image_for_analysis(image),
         {:ok, colors} <- extract_colors_via_sampling(processed_image, num_colors) do
      hex_colors = Enum.map(colors, &rgb_to_hex/1)
      {:ok, hex_colors}
    end
  end

  @doc """
  Same as `extract-dominant_colors/2`, but raises an error if extraction fails.
  """
  @spec extract_dominant_colors!(binary(), pos_integer()) :: [String.t()] | no_return
  def extract_dominant_colors!(image_data, num_colors \\ 5) do
    case extract_dominant_colors(image_data, num_colors) do
      {:ok, colors} -> colors
      {:error, reason} -> raise "Failed to extract dominant colors: #{inspect(reason)}"
    end
  end

  defp prepare_image_for_analysis(image) do
    with {:ok, resized} <- Operation.thumbnail_image(image, 1000) do
      ensure_rgb_channels(resized)
    end
  end

  defp ensure_rgb_channels(image) do
    bands = Image.bands(image)

    cond do
      bands >= 3 ->
        # Image already has 3+ channels (RGB or RGBA), use as-is
        {:ok, image}

      bands == 1 ->
        # Grayscale image, convert to 3-channel by copying the single channel
        Operation.bandjoin([image, image, image])

      true ->
        {:error, "Unsupported image format with #{bands} bands"}
    end
  end

  defp extract_colors_via_sampling(image, num_colors) do
    width = Image.width(image)
    height = Image.height(image)

    # Sample every nth pixel to get a good distribution
    sample_step = max(1, div(min(width, height), 10))

    pixels =
      for y <- 0..(height - 1)//sample_step,
          x <- 0..(width - 1)//sample_step do
        case Operation.getpoint(image, x, y) do
          {:ok, [r, g, b | _]} ->
            {trunc(r), trunc(g), trunc(b)}

          {:ok, [gray]} ->
            gray_val = trunc(gray)
            {gray_val, gray_val, gray_val}

          {:ok, [r, g]} ->
            # Handle 2-channel images
            {trunc(r), trunc(g), 0}

          _ ->
            nil
        end
      end
      |> Enum.reject(fn
        {r, g, b} ->
          # Filter out very dark or very light colors
          brightness = (r + g + b) / 3
          brightness < 20 || brightness > 235

        nil ->
          true
      end)

    if Enum.empty?(pixels) do
      {:error, "No valid pixels found for color extraction"}
    else
      colors = analyze_color_histogram(pixels, num_colors)
      {:ok, colors}
    end
  end

  defp analyze_color_histogram(pixels, num_colors) do
    # Simple frequency-based approach with color grouping
    pixels
    |> group_similar_colors()
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_color, count} -> count end, :desc)
    |> Enum.take(num_colors)
    |> Enum.map(fn {{r, g, b}, _count} -> {r, g, b} end)
  end

  defp group_similar_colors(pixels) do
    Enum.map(pixels, fn {r, g, b} ->
      # Group colors into buckets to reduce similar colors
      bucket_size = 64
      grouped_r = div(r, bucket_size) * bucket_size
      grouped_g = div(g, bucket_size) * bucket_size
      grouped_b = div(b, bucket_size) * bucket_size
      {grouped_r, grouped_g, grouped_b}
    end)
  end

  defp rgb_to_hex({r, g, b}) do
    "#" <>
      (Integer.to_string(r, 16) |> String.pad_leading(2, "0") |> String.upcase()) <>
      (Integer.to_string(g, 16) |> String.pad_leading(2, "0") |> String.upcase()) <>
      (Integer.to_string(b, 16) |> String.pad_leading(2, "0") |> String.upcase())
  end
end
