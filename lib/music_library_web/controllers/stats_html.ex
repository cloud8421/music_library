defmodule MusicLibraryWeb.StatsHTML do
  use MusicLibraryWeb, :html

  alias MusicLibrary.Records.Record

  embed_templates "stats_html/*"

  defp format_records_count(records_count_by_format) do
    Enum.map(records_count_by_format, fn {format, count} ->
      Integer.to_string(count) <> " " <> Record.format_long_label(format)
    end)
    |> Enum.join(", ")
  end
end
