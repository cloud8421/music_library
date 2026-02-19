defmodule MusicBrainz.ReleaseSearchResult do
  alias MusicBrainz.ReleaseGroup

  @enforce_keys [:id, :title, :release_group, :artists, :date, :barcode, :media]
  defstruct [:id, :title, :release_group, :artists, :date, :barcode, :media]

  def from_api_response(r) do
    %__MODULE__{
      id: r["id"],
      title: r["title"],
      release_group: r["release-group"] && parse_release_group(r["release-group"]),
      artists: Enum.map_join(r["artist-credit"] || [], ", ", fn ac -> ac["artist"]["name"] end),
      date: r["date"],
      barcode: r["barcode"],
      media: parse_media(r["media"])
    }
  end

  def format(release_search_result) do
    sorted_frequencies =
      release_search_result.media
      |> Enum.frequencies_by(& &1.format)
      |> Enum.sort_by(fn {_, count} -> count end)

    case sorted_frequencies do
      [{format, _}] -> parse_format(format)
      _ -> :multi
    end
  end

  defp parse_release_group(rg) do
    %{
      id: rg["id"],
      type: ReleaseGroup.parse_type(rg["primary-type"]),
      title: rg["title"]
    }
  end

  def parse_media(media) do
    Enum.map(media, fn m ->
      %{
        format: m["format"],
        track_count: m["track-count"],
        disc_count: m["disc-count"]
      }
    end)
  end

  defp parse_format(nil), do: :unknown
  defp parse_format("CD"), do: :cd
  defp parse_format("DVD-Audio"), do: :dvd
  defp parse_format("DVD-Video"), do: :dvd
  defp parse_format("DVD"), do: :dvd
  defp parse_format("Blu-ray"), do: :blu_ray
  defp parse_format("Digital Media"), do: :digital_download

  defp parse_format(format) do
    cond do
      String.contains?(format, "Vinyl") -> :vinyl
      String.contains?(format, "CD") -> :cd
      String.contains?(format, "VHS") -> :vhs
      true -> :unknown
    end
  end
end
