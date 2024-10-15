defmodule MusicLibraryWeb.StatsHTML do
  use MusicLibraryWeb, :html

  alias MusicLibrary.Records.Record

  embed_templates "stats_html/*"
end
