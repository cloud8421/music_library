defmodule MusicBrainz.ReleaseSearchResult do
  @moduledoc false

  alias MusicBrainz.ReleaseGroup

  @enforce_keys [:id, :title, :release_group, :artists, :date, :barcode, :media]
  defstruct [:id, :title, :release_group, :artists, :date, :barcode, :media]

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          release_group: map() | nil,
          artists: String.t(),
          date: String.t() | nil,
          barcode: String.t() | nil,
          media: [map()]
        }

  @spec from_api_response(map()) :: t()
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

  @doc """
  Returns the physical format of a release based on its media.

  Returns `:multi` when a release contains different format types.

  ## Examples

      iex> MusicBrainz.ReleaseSearchResult.format(%MusicBrainz.ReleaseSearchResult{
      ...>   id: "1", title: "T", release_group: nil, artists: "A", date: "2000", barcode: "0",
      ...>   media: [%{format: "CD", disc_count: 1, track_count: 11}]
      ...> })
      :cd

      iex> MusicBrainz.ReleaseSearchResult.format(%MusicBrainz.ReleaseSearchResult{
      ...>   id: "1", title: "T", release_group: nil, artists: "A", date: "2000", barcode: "0",
      ...>   media: [%{format: "12\\" Vinyl", disc_count: 0, track_count: 8}]
      ...> })
      :vinyl

      iex> MusicBrainz.ReleaseSearchResult.format(%MusicBrainz.ReleaseSearchResult{
      ...>   id: "1", title: "T", release_group: nil, artists: "A", date: "2000", barcode: "0",
      ...>   media: [
      ...>     %{format: "CD", disc_count: 1, track_count: 10},
      ...>     %{format: "CD", disc_count: 1, track_count: 9}
      ...>   ]
      ...> })
      :cd

      iex> MusicBrainz.ReleaseSearchResult.format(%MusicBrainz.ReleaseSearchResult{
      ...>   id: "1", title: "T", release_group: nil, artists: "A", date: "2000", barcode: "0",
      ...>   media: [
      ...>     %{format: "CD", disc_count: 0, track_count: 11},
      ...>     %{format: "DVD-Video", disc_count: 0, track_count: 22}
      ...>   ]
      ...> })
      :multi

  """
  @spec format(t()) ::
          :cd | :vinyl | :dvd | :blu_ray | :digital_download | :vhs | :multi | :unknown
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

  @spec parse_media([map()]) :: [map()]
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
