defmodule MusicLibrary.Colors.KMeansExtractorTest do
  use ExUnit.Case

  alias MusicLibrary.Colors.KMeansExtractor

  @image_data MusicLibrary.Fixtures.Records.marbles_cover_data()

  describe "extract_dominant_colors/1" do
    test "extracts 5 colors by default" do
      assert {:ok, ["#101111", "#d3b696", "#836246", "#5d412d", "#3c2e22"]} ==
               KMeansExtractor.extract_dominant_colors(@image_data)
    end

    test "extracts custom number of colors" do
      assert {:ok, ["#101111", "#d3b696", "#836246"]} ==
               KMeansExtractor.extract_dominant_colors(@image_data, 3)
    end
  end
end
