defmodule MusicLibrary.ColorHelpers do
  @moduledoc false

  @doc """
  Returns true if the given string is a valid lowercase hex color code.

      iex> MusicLibrary.ColorHelpers.color_hex?("#d3b696")
      true

      iex> MusicLibrary.ColorHelpers.color_hex?("not a color")
      false
  """
  def color_hex?(value), do: String.match?(value, ~r/^#[0-9a-f]{6}$/)
end
