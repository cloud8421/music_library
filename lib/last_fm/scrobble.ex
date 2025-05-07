defmodule LastFm.Scrobble do
  defstruct [:track, :artist, :timestamp, :album, :album_artist, :mbid]

  def encode(scrobble) do
    scrobble
    |> Map.from_struct()
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end
end
