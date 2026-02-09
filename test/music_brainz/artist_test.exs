defmodule MusicBrainz.ArtistTest do
  use ExUnit.Case, async: true

  alias MusicBrainz.Artist

  describe "get_wikidata_id/1" do
    test "extracts wikidata ID from relations" do
      artist_data = MusicBrainz.Fixtures.Artist.get_artist()
      artist = Artist.from_api_response(artist_data)

      assert Artist.get_wikidata_id(artist) == "Q352766"
    end

    test "returns nil when no wikidata relation exists" do
      artist = %Artist{
        id: "test",
        name: "Test",
        sort_name: "Test",
        relations: [
          %{type: "discogs", url: %{"resource" => "https://www.discogs.com/artist/123"}}
        ]
      }

      assert Artist.get_wikidata_id(artist) == nil
    end
  end
end
