defmodule MusicLibrary.FormatNumber do
  @moduledoc """
  Provides utilities for formatting numbers with human-readable suffixes.

  ## Examples

      iex> MusicLibrary.FormatNumber.to_compact(96591)
      "96.6k"

      iex> MusicLibrary.FormatNumber.to_compact(1234)
      "1.2k"

      iex> MusicLibrary.FormatNumber.to_compact(999)
      "999"

      iex> MusicLibrary.FormatNumber.to_compact(1500000)
      "1.5M"

      iex> MusicLibrary.FormatNumber.to_compact(2000000000)
      "2.0B"

      iex> MusicLibrary.FormatNumber.to_compact(0)
      "0"
  """

  @doc """
  Converts an integer to a compact string representation using k, M, B suffixes.

  Numbers less than 1,000 are returned as-is.
  Numbers 1,000 and above are formatted with appropriate suffix and one decimal place.
  """
  def to_compact(number) when is_integer(number) and number < 1000 do
    Integer.to_string(number)
  end

  def to_compact(number) when is_integer(number) and number < 1_000_000 do
    format_with_suffix(number / 1000, "k")
  end

  def to_compact(number) when is_integer(number) and number < 1_000_000_000 do
    format_with_suffix(number / 1_000_000, "M")
  end

  def to_compact(number) when is_integer(number) do
    format_with_suffix(number / 1_000_000_000, "B")
  end

  defp format_with_suffix(value, suffix) do
    "#{:erlang.float_to_binary(value, decimals: 1)}#{suffix}"
  end
end
