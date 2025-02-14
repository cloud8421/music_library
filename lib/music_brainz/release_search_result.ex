defmodule MusicBrainz.ReleaseSearchResult do
  @enforce_keys [:id, :title, :release_group, :artists, :date, :barcode, :media]
  defstruct [:id, :title, :release_group, :artists, :date, :barcode, :media]

  alias MusicBrainz.ReleaseGroup

  def from_api_response(r) do
    %__MODULE__{
      id: r["id"],
      title: r["title"],
      release_group: parse_release_group(r["release-group"]),
      artists:
        r["artist-credit"]
        |> Enum.map(fn ac -> ac["artist"]["name"] end)
        |> Enum.join(", "),
      date: r["date"],
      barcode: r["barcode"],
      media: parse_media(r["media"])
    }
  end

  defp parse_release_group(rg) do
    %{
      id: rg["id"],
      type: ReleaseGroup.parse_type(rg["primary-type"]),
      title: rg["title"]
    }
  end

  defp parse_media(media) do
    Enum.map(media, fn m ->
      %{
        format: m["format"],
        track_count: m["track-count"],
        disc_count: m["disc-count"]
      }
    end)
  end
end
