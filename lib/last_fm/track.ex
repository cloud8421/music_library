defmodule LastFm.Track do
  @moduledoc """
  Data is not always guaranteed:

  - musicbrainz_id can be an empty string
  """

  use Ecto.Schema

  import Ecto.Changeset

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

    embeds_one :artist, Artist, on_replace: :update
    embeds_one :album, Album, on_replace: :update

    field :last_fm_data, :map, default: %{}
  end

  def from_api_response(raw_tracks) do
    raw_tracks
    |> Enum.reject(&now_playing?/1)
    |> Enum.map(fn t ->
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

  defp now_playing?(raw_track) do
    get_in(raw_track, ["@attr", "nowplaying"]) == "true"
  end

  defp parse_cover_url(track) do
    track["image"]
    |> Enum.find(%{"#text" => nil}, fn i -> i["size"] == "medium" end)
    |> Map.get("#text")
  end

  defp parse_scrobble_at_uts(track) do
    case Integer.parse(track["date"]["uts"]) do
      {int, ""} -> int
      _ -> nil
    end
  end

  def changeset(track, attrs) do
    track
    |> cast(attrs, [
      :scrobbled_at_uts,
      :musicbrainz_id,
      :title,
      :cover_url,
      :scrobbled_at_label,
      :last_fm_data
    ])
    |> cast_embed(:artist)
    |> cast_embed(:album)
    |> validate_required([:scrobbled_at_uts, :title])
  end
end
