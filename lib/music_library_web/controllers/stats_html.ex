defmodule MusicLibraryWeb.StatsHTML do
  use MusicLibraryWeb, :html

  import MusicLibraryWeb.ArtistHelpers

  alias MusicLibrary.Records.Record

  embed_templates "stats_html/*"

  defp format_records_count(records_count_by_format) do
    records_count_by_format
    |> Enum.sort_by(fn {_format, count} -> count end, :desc)
    |> Enum.map(fn {format, count} ->
      Integer.to_string(count) <> " " <> Record.format_long_label(format)
    end)
    |> Enum.join(", ")
  end
end
