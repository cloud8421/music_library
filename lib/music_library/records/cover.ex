defmodule MusicLibrary.Records.Cover do
  @size 600

  @fallback_path Application.app_dir(:music_library, ["priv", "cover-not-found.jpg"])

  @external_resource @fallback_path

  @fallback_data File.read!(@fallback_path)

  def fallback_data, do: @fallback_data

  def resize(cover_data, size \\ @size) do
    {:ok, thumb} = Vix.Vips.Operation.thumbnail_buffer(cover_data, size)
    Vix.Vips.Image.write_to_buffer(thumb, ".jpg")
  end

  def hash(cover_data) do
    :crypto.hash(:sha256, cover_data) |> Base.encode16()
  end

  def correct_size?(cover_data) do
    {:ok, image} = Vix.Vips.Image.new_from_buffer(cover_data)

    Vix.Vips.Image.width(image) == @size
  end
end
