defmodule MusicBrainz.ReleaseGroupSearchResult do
  @enforce_keys [:id, :type, :title, :artists, :release]
  defstruct [:id, :type, :title, :artists, :release]

  def from_api_response(rg) do
    %__MODULE__{
      id: rg["id"],
      type: parse_subtype(rg["primary-type"]),
      title: rg["title"],
      artists:
        rg["artist-credit"]
        |> Enum.map(fn ac -> ac["artist"]["name"] end)
        |> Enum.join(", "),
      release: rg["first-release-date"]
    }
  end

  defp parse_subtype("Album"), do: :album
  defp parse_subtype("EP"), do: :ep
  defp parse_subtype("Live"), do: :live
  defp parse_subtype("Compilation"), do: :compilation
  defp parse_subtype("Single"), do: :single
  defp parse_subtype(_), do: :other
end
