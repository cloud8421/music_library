defmodule MusicLibrary.ArtistInfoFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MusicLibrary.Artists.ArtistInfo` schema.
  """

  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibrary.Repo

  def artist_info_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          id: Ecto.UUID.generate(),
          musicbrainz_data: %{"name" => "Test Artist"}
        },
        attrs
      )

    Repo.insert!(struct!(ArtistInfo, attrs))
  end
end
