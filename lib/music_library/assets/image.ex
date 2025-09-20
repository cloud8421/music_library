defmodule MusicLibrary.Assets.Image do
  alias Vix.Vips.{Image, Operation}

  fallback_path = Application.app_dir(:music_library, ["priv", "image-not-found.jpg"])
  fallback_data = File.read!(fallback_path)

  @external_resource fallback_path

  @default_size 2000
  @default_format "image/jpeg"

  def fallback_data, do: unquote(fallback_data)

  def resize(cover_data, size \\ @default_size, format \\ @default_format) do
    {:ok, thumb} = Operation.thumbnail_buffer(cover_data, size)
    Image.write_to_buffer(thumb, extension(format))
  end

  def convert(cover_data, data_format, target_format) do
    if data_format == target_format do
      {:ok, cover_data}
    else
      {:ok, image} = Image.new_from_buffer(cover_data)
      Image.write_to_buffer(image, extension(target_format))
    end
  end

  defp extension("image/jpeg"), do: ".jpg"
  defp extension("image/webp"), do: ".webp"
end
