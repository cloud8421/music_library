defmodule MusicBrainz.ReleaseGroup do
  alias MusicBrainz.ReleaseGroupSearchResult

  def included_release_groups(release_group) do
    release_group
    |> get_release_groups()
    |> Enum.map(fn relation ->
      ReleaseGroupSearchResult.from_api_response(relation["release_group"])
    end)
  end

  def release_ids(release_group) do
    release_group
    |> Map.get("releases", [])
    |> Enum.map(fn release -> release["id"] end)
  end

  def included_release_group_ids(release_group) do
    release_group
    |> included_release_groups()
    |> Enum.map(fn rg -> rg.id end)
  end

  def url(id) do
    "https://musicbrainz.org/release-group/#{id}"
  end

  def parse_type("Album"), do: :album
  def parse_type("EP"), do: :ep
  def parse_type("Live"), do: :live
  def parse_type("Compilation"), do: :compilation
  def parse_type("Single"), do: :single
  def parse_type(_), do: :other

  defp get_release_groups(release_group) do
    release_group
    |> Map.get("relations", [])
    |> Enum.filter(fn relation ->
      relation["target-type"] == "release_group" and
        relation["type"] == "included in" and
        relation["direction"] == "backward"
    end)
  end
end
