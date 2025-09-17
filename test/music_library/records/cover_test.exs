defmodule MusicLibrary.Records.CoverTest do
  use ExUnit.Case, async: true

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records.Cover

  describe "resize/1" do
    test "it resizes to the desired size" do
      # Use the cached cover data which is much faster than reading from disk
      cover_data = marbles_cover_data()
      {:ok, resized_cover} = Cover.resize(cover_data)
      assert cover_data !== resized_cover
    end
  end
end
