defmodule MusicBrainz.ReleaseGroupSearchResult do
  @enforce_keys [:id, :type, :title, :artists, :release]
  defstruct [:id, :type, :title, :artists, :release]

  alias MusicBrainz.ReleaseGroup

  def from_api_response(rg) do
    %__MODULE__{
      id: rg["id"],
      type: ReleaseGroup.parse_subtype(rg["primary-type"]),
      title: rg["title"],
      artists:
        rg["artist-credit"]
        |> Enum.map(fn ac -> ac["artist"]["name"] end)
        |> Enum.join(", "),
      release: rg["first-release-date"]
    }
  end
end
