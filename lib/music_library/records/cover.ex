defmodule MusicLibrary.Records.Cover do
  alias Vix.Vips.{Image, Operation}

  fallback_path = Application.app_dir(:music_library, ["priv", "cover-not-found.jpg"])
  fallback_data = File.read!(fallback_path)

  @external_resource fallback_path

  @size 600

  def fallback_data, do: unquote(fallback_data)

  def resize(cover_data, size \\ @size) do
    {:ok, thumb} = Operation.thumbnail_buffer(cover_data, size)
    Image.write_to_buffer(thumb, ".jpg")
  end

  def hash(cover_data) do
    :crypto.hash(:sha256, cover_data) |> Base.encode16()
  end

  def correct_size?(cover_data) do
    {:ok, image} = Image.new_from_buffer(cover_data)

    Image.width(image) == @size
  end
end
