defmodule MusicLibrary.Records.Cover do
  @size 600

  def resize(cover_data) do
    {:ok, thumb} = Vix.Vips.Operation.thumbnail_buffer(cover_data, @size)
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
