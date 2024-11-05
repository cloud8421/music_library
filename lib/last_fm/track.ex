defmodule LastFm.Track do
  @moduledoc """
  Data is not always guaranteed:

  - musicbrainz_id can be an empty string
  """

  alias LastFm.{Album, Artist}

  defstruct [
    :musicbrainz_id,
    :title,
    :artist,
    :album,
    :cover_url,
    :scrobbled_at_uts,
    :scrobbled_at_label
  ]

  def from_api_response(raw_tracks) do
    Enum.map(raw_tracks, fn t ->
      album = %Album{
        musicbrainz_id: t["album"]["mbid"],
        title: t["album"]["#text"]
      }

      artist = %Artist{
        musicbrainz_id: t["artist"]["mbid"],
        name: t["artist"]["#text"]
      }

      %__MODULE__{
        musicbrainz_id: t["mbid"],
        title: t["name"],
        artist: artist,
        album: album,
        cover_url: parse_cover_url(t),
        scrobbled_at_uts: parse_scrobble_at_uts(t),
        scrobbled_at_label: t["date"]["#text"]
      }
    end)
  end

  defp parse_cover_url(track) do
    track["image"]
    |> Enum.find(%{"#text" => nil}, fn i -> i["size"] == "medium" end)
    |> Map.get("#text")
  end

  defp parse_scrobble_at_uts(track) do
    track["date"]["uts"]
    |> String.to_integer()
  end
end
