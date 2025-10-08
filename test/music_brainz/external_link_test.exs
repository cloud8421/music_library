defmodule MusicBrainz.ExternalLinkTest do
  use ExUnit.Case, async: true

  alias MusicBrainz.ExternalLink
  alias MusicBrainz.Fixtures.Artist

  setup do
    %{artist_data: Artist.get_artist()}
  end

  describe "external_links/2 with a single pattern" do
    test "returns empty list when relations key is missing" do
      assert ExternalLink.external_links(%{}, "spotify") == []
    end

    test "returns empty list when no URLs match the pattern", %{artist_data: artist_data} do
      assert ExternalLink.external_links(artist_data, "nonexistent-pattern") == []
    end

    test "returns URLs matching the pattern", %{artist_data: artist_data} do
      results = ExternalLink.external_links(artist_data, "spotify")

      assert length(results) == 1
      assert "https://open.spotify.com/artist/4X42BfuhWCAZ2swiVze9O0" in results
    end

    test "returns all URLs matching the pattern when multiple exist", %{artist_data: artist_data} do
      results = ExternalLink.external_links(artist_data, "youtube")

      assert length(results) == 2
      assert "https://www.youtube.com/user/StevenWilsonHQ" in results
      assert "https://music.youtube.com/channel/UCN_yfO7km9qK5n9JlLJRdrg" in results
    end

    test "returns all URLs when pattern is nil", %{artist_data: artist_data} do
      results = ExternalLink.external_links(artist_data, nil)

      # The fixture has 59 relations with URLs
      assert length(results) == 59
    end

    test "pattern matching is case-sensitive", %{artist_data: artist_data} do
      # Should not match because 'Spotify' != 'spotify'
      assert ExternalLink.external_links(artist_data, "Spotify") == []
    end

    test "pattern matches substring of URL", %{artist_data: artist_data} do
      results = ExternalLink.external_links(artist_data, "discogs")

      assert length(results) == 1
      assert "https://www.discogs.com/artist/227943" in results
    end
  end

  describe "external_links/2 with pattern map" do
    test "returns empty list when no patterns match", %{artist_data: artist_data} do
      patterns = %{
        fake1: "nonexistent1",
        fake2: "nonexistent2"
      }

      assert ExternalLink.external_links(artist_data, patterns) == []
    end

    test "returns external link structs with names and URLs", %{artist_data: artist_data} do
      patterns = %{
        spotify: "spotify",
        discogs: "discogs"
      }

      results = ExternalLink.external_links(artist_data, patterns)

      assert length(results) == 2

      spotify_link = Enum.find(results, fn link -> link.name == :spotify end)
      assert spotify_link.url == "https://open.spotify.com/artist/4X42BfuhWCAZ2swiVze9O0"

      discogs_link = Enum.find(results, fn link -> link.name == :discogs end)
      assert discogs_link.url == "https://www.discogs.com/artist/227943"
    end

    test "returns only first matching URL when multiple URLs match same pattern", %{
      artist_data: artist_data
    } do
      patterns = %{
        youtube: "youtube"
      }

      results = ExternalLink.external_links(artist_data, patterns)

      assert length(results) == 1
      assert [youtube_link] = results
      assert youtube_link.name == :youtube

      # Should return the first matching URL
      assert youtube_link.url in [
               "https://www.youtube.com/user/StevenWilsonHQ",
               "https://music.youtube.com/channel/UCN_yfO7km9qK5n9JlLJRdrg"
             ]
    end

    test "handles mix of matching and non-matching patterns", %{artist_data: artist_data} do
      patterns = %{
        spotify: "spotify",
        bandcamp: "bandcamp",
        discogs: "discogs"
      }

      results = ExternalLink.external_links(artist_data, patterns)

      # Only spotify and discogs should match
      assert length(results) == 2

      names = Enum.map(results, & &1.name)
      assert :spotify in names
      assert :discogs in names
      refute :bandcamp in names
    end

    test "returns ExternalLink structs with correct structure", %{artist_data: artist_data} do
      patterns = %{
        lastfm: "last.fm"
      }

      results = ExternalLink.external_links(artist_data, patterns)

      assert [link] = results
      assert %ExternalLink{} = link
      assert link.name == :lastfm
      assert link.url == "https://www.last.fm/music/Steven+Wilson"
    end

    test "handles empty pattern map", %{artist_data: artist_data} do
      assert ExternalLink.external_links(artist_data, %{}) == []
    end
  end
end
