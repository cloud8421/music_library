defmodule MusicBrainz.ReleaseGroupSearchResult do
  @enforce_keys [:id, :type, :title, :artists, :release]
  defstruct [:id, :type, :title, :artists, :release]

  alias MusicBrainz.ReleaseGroup

  def from_api_response(rg) do
    %__MODULE__{
      id: rg["id"],
      type: ReleaseGroup.parse_type(rg["primary-type"]),
      title: rg["title"],
      artists: Enum.map_join(rg["artist-credit"], ", ", fn ac -> ac["artist"]["name"] end),
      release: rg["first-release-date"]
    }
  end

  def thumb_url(rgr) do
    "https://coverartarchive.org/release-group/#{rgr.id}/front-250"
  end
end
