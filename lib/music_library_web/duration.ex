defmodule MusicLibraryWeb.Duration do
  @moduledoc """
  Formats durations from milliseconds to human-readable strings.
  """

  @doc """
  Formats a duration in milliseconds as a human-readable string.

  ## Examples

      iex> MusicLibraryWeb.Duration.format_duration(30_000)
      "0:30"

      iex> MusicLibraryWeb.Duration.format_duration(90_000)
      "1:30"

      iex> MusicLibraryWeb.Duration.format_duration(3_723_000)
      "1:02:03"

      iex> MusicLibraryWeb.Duration.format_duration(0)
      "0:00"

  """
  def format_duration(milliseconds) do
    milliseconds
    |> System.convert_time_unit(:millisecond, :second)
    |> format_seconds()
  end

  defp format_seconds(seconds) when seconds <= 59 do
    "0:#{zero_pad(seconds)}"
  end

  defp format_seconds(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    format_minutes(minutes, remaining_seconds)
  end

  defp format_minutes(minutes, seconds) when minutes <= 59 do
    "#{minutes}:#{zero_pad(seconds)}"
  end

  defp format_minutes(minutes, seconds) do
    hours = div(minutes, 60)
    remaining_minutes = rem(minutes, 60)

    format_hours(hours, remaining_minutes, seconds)
  end

  defp format_hours(hours, minutes, seconds) do
    "#{hours}:#{zero_pad(minutes)}:#{zero_pad(seconds)}"
  end

  defp zero_pad(integer) do
    integer
    |> to_string()
    |> String.pad_leading(2, "0")
  end
end
