defmodule MusicLibrary.Records.Cover do
  def resize(cover_data) do
    {:ok, thumb} = Vix.Vips.Operation.thumbnail_buffer(cover_data, 600)
    Vix.Vips.Image.write_to_buffer(thumb, ".jpg")
  end
end
