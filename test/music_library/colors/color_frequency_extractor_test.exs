defmodule MusicLibrary.Colors.ColorFrequencyExtractorTest do
  use ExUnit.Case

  alias MusicLibrary.Colors.ColorFrequencyExtractor

  @image_data MusicLibrary.Fixtures.Records.marbles_cover_data()

  describe "extract_dominant_colors/1" do
    @describetag :slow

    test "extracts colors from an image" do
      assert {:ok, colors} = ColorFrequencyExtractor.extract_dominant_colors(@image_data)

      assert is_list(colors)
      assert colors == ["#000000", "#C08080", "#400000", "#C0C0C0", "#404000"]
    end

    test "extracts custom number of colors" do
      assert {:ok, colors} = ColorFrequencyExtractor.extract_dominant_colors(@image_data, 3)

      assert colors == ["#000000", "#C08080", "#400000"]
    end
  end

  describe "extract_dominant_colors!/1" do
    @describetag :slow

    test "extracts colors or raises" do
      colors = ColorFrequencyExtractor.extract_dominant_colors!(@image_data)

      assert colors == ["#000000", "#C08080", "#400000", "#C0C0C0", "#404000"]
    end
  end
end
