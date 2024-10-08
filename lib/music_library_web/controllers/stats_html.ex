defmodule MusicLibraryWeb.StatsHTML do
  use MusicLibraryWeb, :html

  import MusicLibraryWeb.ArtistHelpers

  alias MusicLibrary.Records.Record

  embed_templates "stats_html/*"
end
