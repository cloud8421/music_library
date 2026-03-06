defmodule MusicBrainz.ReleaseGroupSearchResult do
  alias MusicBrainz.ReleaseGroup

  @enforce_keys [:id, :type, :title, :artists, :release_date]
  defstruct [:id, :type, :title, :artists, :release_date]

  @type t :: %__MODULE__{
          id: String.t(),
          type: :album | :ep | :live | :compilation | :single | :other,
          title: String.t(),
          artists: String.t(),
          release_date: String.t() | nil
        }

  @spec from_api_response(map()) :: t()
  def from_api_response(rg) do
    %__MODULE__{
      id: rg["id"],
      type: ReleaseGroup.parse_type(rg["primary-type"]),
      title: rg["title"],
      artists: Enum.map_join(rg["artist-credit"], ", ", fn ac -> ac["artist"]["name"] end),
      release_date: rg["first-release-date"]
    }
  end

  @spec thumb_url(t()) :: String.t()
  def thumb_url(rgr) do
    "https://coverartarchive.org/release-group/#{rgr.id}/front-250"
  end
end
