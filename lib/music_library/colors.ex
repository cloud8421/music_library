defmodule MusicLibrary.Colors do
  alias MusicLibrary.Colors.{ColorFrequencyExtractor, EdgeWeightedExtractor}

  def extract_colors(image_data, :fast) do
    ColorFrequencyExtractor.extract_dominant_colors(image_data)
  end

  def extract_colors(image_data, :slow) do
    EdgeWeightedExtractor.extract_dominant_colors(image_data)
  end
end
