defmodule MusicBrainz.ReleaseGroup do
  @moduledoc """
  Helper functions for working with MusicBrainz release group API responses.

  Provides extraction and transformation utilities for release group data,
  including artist credit parsing and type classification.
  """

  alias MusicBrainz.ReleaseGroupSearchResult

  @spec included_release_groups(map()) :: [ReleaseGroupSearchResult.t()]
  def included_release_groups(release_group) do
    release_group
    |> get_release_groups()
    |> Enum.map(fn relation ->
      ReleaseGroupSearchResult.from_api_response(relation["release_group"])
    end)
  end

  @spec releases(map()) :: [map()]
  def releases(release_group) do
    release_group
    |> Map.get("releases", [])
  end

  @spec release_ids(map()) :: [String.t()]
  def release_ids(release_group) do
    release_group
    |> Map.get("releases", [])
    |> Enum.map(fn release -> release["id"] end)
  end

  @spec included_release_group_ids(map()) :: [String.t()]
  def included_release_group_ids(release_group) do
    release_group
    |> included_release_groups()
    |> Enum.map(fn rg -> rg.id end)
  end

  @spec url(String.t()) :: String.t()
  def url(id) do
    "https://musicbrainz.org/release-group/#{id}"
  end

  @spec parse_type(String.t() | nil) :: :album | :ep | :live | :compilation | :single | :other
  def parse_type("Album"), do: :album
  def parse_type("EP"), do: :ep
  def parse_type("Live"), do: :live
  def parse_type("Compilation"), do: :compilation
  def parse_type("Single"), do: :single
  def parse_type(_), do: :other

  @doc """
  Parses artist credits from a MusicBrainz release group API response.

  Extracts the `artist-credit` array and maps each artist into a map
  suitable for use as an embedded artist in the application `Record` schema.

  Returns a list of maps with keys: `:name`, `:musicbrainz_id`, `:sort_name`,
  `:disambiguation`, and `:joinphrase`.
  """
  @spec parse_artist_credits(map()) :: [map()]
  def parse_artist_credits(musicbrainz_data) do
    musicbrainz_data
    |> get_in(["artist-credit", Access.all()])
    |> Enum.map(fn artist_credit ->
      %{
        name: artist_credit["artist"]["name"],
        musicbrainz_id: artist_credit["artist"]["id"],
        sort_name: artist_credit["artist"]["sort-name"],
        disambiguation: artist_credit["artist"]["disambiguation"],
        joinphrase: artist_credit["joinphrase"]
      }
    end)
  end

  @doc """
  Determines the application record type from MusicBrainz release group type fields.

  Maps the `primary-type` and `secondary-types` fields from a MusicBrainz
  release group API response to the application's record type enum values
  (`:album`, `:ep`, `:live`, `:compilation`, `:single`, `:other`).
  """
  @spec parse_record_type(String.t() | nil, [String.t()] | nil) :: atom()
  def parse_record_type("Album", secondary_types) when is_list(secondary_types) do
    cond do
      "Live" in secondary_types -> :live
      "Compilation" in secondary_types -> :compilation
      true -> :album
    end
  end

  def parse_record_type("Album", _secondary_types), do: :album
  def parse_record_type("EP", _secondary_types), do: :ep
  def parse_record_type("Single", _secondary_types), do: :single
  def parse_record_type(_primary_type, _secondary_types), do: :other

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
