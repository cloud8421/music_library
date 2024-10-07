defmodule MusicLibraryWeb.ArtistHelpers do
  def format_artist_names(artists) do
    artists
    |> Enum.map(fn a -> a.name end)
    |> Enum.join(", ")
  end
end
