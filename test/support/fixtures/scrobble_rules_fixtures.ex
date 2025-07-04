defmodule MusicLibrary.ScrobbleRulesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MusicLibrary.ScrobbleRules` context.
  """

  alias MusicLibrary.ScrobbleRules

  @doc """
  Generate a scrobble_rule.
  """
  def scrobble_rule_fixture(attrs \\ %{}) do
    default_attrs = %{
      type: :album,
      match_value: "Dark Side of the Moon",
      target_musicbrainz_id: "12345678-1234-1234-1234-123456789012",
      enabled: true,
      description: "Fix Pink Floyd album"
    }

    {:ok, scrobble_rule} =
      attrs
      |> Enum.into(default_attrs)
      |> ScrobbleRules.create_scrobble_rule()

    scrobble_rule
  end
end
