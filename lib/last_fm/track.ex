defmodule LastFm.Track do
  @moduledoc """
  Data is not always guaranteed:

  - musicbrainz_id can be an empty string
  """

  use Ecto.Schema

  alias LastFm.{Album, Artist}

  @type t :: %__MODULE__{
          musicbrainz_id: String.t(),
          title: String.t(),
          artist: Artist.t(),
          album: Album.t(),
          cover_url: String.t(),
          scrobbled_at_uts: integer(),
          scrobbled_at_label: String.t(),
          last_fm_data: map()
        }

  @primary_key {:scrobbled_at_uts, :integer, autogenerate: false}
  schema "scrobbled_tracks" do
    field :musicbrainz_id, :string
    field :title, :string
    field :cover_url, :string
    field :scrobbled_at_label, :string

    embeds_one :artist, Artist
    embeds_one :album, Album

    field :last_fm_data, :map, default: %{}
  end

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
        scrobbled_at_label: t["date"]["#text"],
        last_fm_data: t
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
