defmodule MusicLibrary.Colors.Extractor do
  @moduledoc """
  Behaviour that defines the functions necessary to implement a dominant colors
  extractor.
  """

  @callback extract_dominant_colors(binary(), pos_integer()) ::
              {:ok, [String.t()]} | {:error, term()}
end
