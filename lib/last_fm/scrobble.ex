defmodule LastFm.Scrobble do
  defstruct [:track, :artist, :timestamp, :album, :album_artist, :mbid]

  @type t :: %__MODULE__{
          track: String.t(),
          artist: String.t(),
          timestamp: integer(),
          album: String.t() | nil,
          album_artist: String.t() | nil,
          mbid: String.t() | nil
        }

  @spec encode(t()) :: map()
  def encode(scrobble) do
    scrobble
    |> Map.from_struct()
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end
end
