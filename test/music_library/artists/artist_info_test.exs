defmodule MusicLibrary.Artists.ArtistInfoTest do
  use MusicLibrary.DataCase, async: true

  alias MusicLibrary.Artists.ArtistInfo

  describe "country/1" do
    test "returns country from area with ISO 3166-1 codes" do
      artist_info = %ArtistInfo{
        musicbrainz_data: %{
          "area" => %{
            "name" => "United Kingdom",
            "iso-3166-1-codes" => ["GB"]
          }
        }
      }

      assert ArtistInfo.country(artist_info) == %{name: "United Kingdom", code: "GB"}
    end

    test "returns country from area with ISO 3166-2 codes" do
      artist_info = %ArtistInfo{
        musicbrainz_data: %{
          "area" => %{
            "name" => "England",
            "iso-3166-2-codes" => ["GB-ENG"]
          }
        }
      }

      assert ArtistInfo.country(artist_info) == %{name: "England", code: "GB-ENG"}
    end

    test "falls back to top-level country when area has no ISO codes" do
      artist_info = %ArtistInfo{
        musicbrainz_data: %{
          "country" => "US",
          "area" => %{"name" => "United States"}
        }
      }

      assert ArtistInfo.country(artist_info) == %{name: "United States", code: "US"}
    end

    test "returns defaults when area key is missing" do
      artist_info = %ArtistInfo{
        musicbrainz_data: %{}
      }

      assert ArtistInfo.country(artist_info) == %{name: "World", code: "XW"}
    end

    test "falls back to top-level country when area is missing" do
      artist_info = %ArtistInfo{
        musicbrainz_data: %{"country" => "JP"}
      }

      assert ArtistInfo.country(artist_info) == %{name: "World", code: "JP"}
    end
  end
end
