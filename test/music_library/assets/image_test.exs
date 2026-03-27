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
end
