defmodule MusicLibrary.Records.MusicbrainzData do
  def included_release_groups(musicbrainz_data) do
    musicbrainz_data
    |> get_release_groups()
    |> Enum.map(fn relation ->
      MusicBrainz.ReleaseGroup.from_api_response(relation["release_group"])
    end)
  end

  def release_ids(musicbrainz_data) do
    musicbrainz_data
    |> Map.get("releases", [])
    |> Enum.map(fn release -> release["id"] end)
  end

  def included_release_group_ids(musicbrainz_data) do
    musicbrainz_data
    |> included_release_groups()
    |> Enum.map(fn rg -> rg.id end)
  end

  defp get_release_groups(musicbrainz_data) do
    musicbrainz_data
    |> Map.get("relations", [])
    |> Enum.filter(fn relation ->
      relation["target-type"] == "release_group" and
        relation["type"] == "included in" and
        relation["direction"] == "backward"
    end)
  end
end
