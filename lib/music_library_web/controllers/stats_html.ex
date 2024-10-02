defmodule MusicLibraryWeb.StatsHTML do
  use MusicLibraryWeb, :html

  embed_templates "stats_html/*"

  defp format_records_count(records_count_by_format) do
    Enum.map(records_count_by_format, fn {format, count} ->
      Integer.to_string(count) <> " " <> Atom.to_string(format)
    end)
    |> Enum.join(", ")
  end
end
