defmodule MusicLibrary.Assets.Image do
  @moduledoc """
  Image processing via Vix (libvips) for covers and artist images.
  """

  alias Vix.Vips.{Image, Operation}

  fallback_path = Application.app_dir(:music_library, ["priv", "image-not-found.jpg"])
  fallback_data = File.read!(fallback_path)

  @external_resource fallback_path

  @default_size 2000
  @default_format "image/jpeg"

  @spec fallback_data() :: binary()
  def fallback_data, do: unquote(fallback_data)

  @spec resize(binary(), pos_integer(), String.t()) :: {:ok, binary()} | {:error, term()}
  def resize(cover_data, size \\ @default_size, format \\ @default_format) do
    :telemetry.span(
      [:music_library, :assets, :image, :resize],
      %{},
      fn ->
        with {:ok, thumb} <- Operation.thumbnail_buffer(cover_data, size),
             {:ok, _binary} = result <- Image.write_to_buffer(thumb, extension(format)) do
          {result, %{}}
        else
          {:error, _reason} = error -> {error, %{}}
        end
      end
    )
  end

  @spec convert(binary(), String.t(), String.t()) :: {:ok, binary()} | {:error, term()}
  def convert(cover_data, data_format, target_format) do
    if data_format == target_format do
      {:ok, cover_data}
    else
      :telemetry.span(
        [:music_library, :assets, :image, :convert],
        %{},
        fn ->
          with {:ok, image} <- Image.new_from_buffer(cover_data),
               {:ok, _binary} = result <- Image.write_to_buffer(image, extension(target_format)) do
            {result, %{}}
          else
            {:error, _reason} = error -> {error, %{}}
          end
        end
      )
    end
  end

  defp extension("image/jpeg"), do: ".jpg"
  defp extension("image/webp"), do: ".webp"
end
