defmodule MusicLibrary.ArtistInfoFixtures do
  @moduledoc false

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
