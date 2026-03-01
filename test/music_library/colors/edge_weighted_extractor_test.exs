defmodule MusicLibrary.Colors.EdgeWeightedExtractorTest do
  use ExUnit.Case

  alias MusicLibrary.Colors.EdgeWeightedExtractor

  @image_data MusicLibrary.Fixtures.Records.marbles_cover_data()

  describe "extract_dominant_colors/1" do
    @describetag :slow
    test "extracts colors from an image" do
      assert {:ok, colors} =
               EdgeWeightedExtractor.extract_dominant_colors(@image_data)

      assert colors == ["#000000", "#A07850", "#785028", "#502828", "#C8A078"]
    end

    test "extracts custom number of colors" do
      assert {:ok, colors} = EdgeWeightedExtractor.extract_dominant_colors(@image_data, 3)

      assert colors == ["#000000", "#A07850", "#785028"]
    end
  end

  describe "extract_dominant_colors!/1" do
    @describetag :slow
    test "extracts colors or raises" do
      colors = EdgeWeightedExtractor.extract_dominant_colors!(@image_data)

      assert colors == ["#000000", "#A07850", "#785028", "#502828", "#C8A078"]
    end
  end
end
