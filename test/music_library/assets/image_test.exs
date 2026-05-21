defmodule MusicLibrary.Assets.ImageTest do
  use ExUnit.Case, async: true

  alias MusicLibrary.Assets.Image

  describe "resize/1" do
    test "resizes to the desired size" do
      # Use the cached cover data which is much faster than reading from disk
      cover_data = Image.fallback_data()
      {:ok, resized_cover} = Image.resize(cover_data)
      assert cover_data !== resized_cover
    end
  end

  describe "convert/3" do
    test "same-format passthrough returns original binary unchanged" do
      data = Image.fallback_data()
      assert {:ok, result} = Image.convert(data, "image/jpeg", "image/jpeg")
      assert result == data
    end

    test "converts JPEG to WebP successfully" do
      data = Image.fallback_data()
      assert {:ok, webp_data} = Image.convert(data, "image/jpeg", "image/webp")
      assert webp_data != data
      assert byte_size(webp_data) > 0
    end

    test "returns error tuple for invalid image data" do
      assert {:error, _reason} = Image.convert("not an image", "image/jpeg", "image/webp")
    end
  end
end
