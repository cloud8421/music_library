defmodule MusicLibrary.Colors.FakeColorExtractor do
  @moduledoc """
  Test stub for `MusicLibrary.Colors.KMeansExtractor`.

  Returns hardcoded colors to avoid CPU-intensive K-means clustering in tests.
  """

  @behaviour MusicLibrary.Colors.Extractor

  @impl true
  def extract_dominant_colors(_image_data, _num_colors \\ 5) do
    {:ok, ["#000000", "#c0c0c0", "#c08080", "#404000", "#804040"]}
  end
end
