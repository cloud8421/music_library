defmodule MusicLibrary.Records.CoverTest do
  use ExUnit.Case, async: true

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records.Cover

  describe "resize/1" do
    test "it resizes to the desired size" do
      cover_data = File.read!(marbles_cover_fixture())
      {:ok, resized_cover} = Cover.resize(cover_data)
      assert cover_data !== resized_cover
      assert Cover.correct_size?(resized_cover)
    end
  end
end
