defmodule MusicLibrary.Colors.KMeansExtractorTest do
  use ExUnit.Case

  import MusicLibrary.ColorHelpers, only: [color_hex?: 1]

  alias MusicLibrary.Colors.KMeansExtractor

  @image_data MusicLibrary.Fixtures.Records.marbles_cover_data()

  describe "extract_dominant_colors/1" do
    test "extracts 5 colors by default" do
      assert {:ok, colors} = KMeansExtractor.extract_dominant_colors(@image_data)
      assert length(colors) == 5
      assert Enum.all?(colors, &color_hex?/1)
    end

    test "extracts custom number of colors" do
      assert {:ok, colors} = KMeansExtractor.extract_dominant_colors(@image_data, 3)
      assert length(colors) == 3
      assert Enum.all?(colors, &color_hex?/1)
    end
  end
end
