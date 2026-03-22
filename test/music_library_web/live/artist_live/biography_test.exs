defmodule MusicLibraryWeb.ArtistLive.BiographyTest do
  use MusicLibrary.DataCase, async: true

  alias MusicLibraryWeb.ArtistLive.Biography

  import MusicLibrary.ArtistInfoFixtures

  describe "build/1" do
    test "returns biography map when Wikipedia data is present" do
      artist_info =
        artist_info_fixture(%{
          wikipedia_data: %{
            "intro_html" => "<p>A musician from England.</p>",
            "extract" => "A musician from England.",
            "content_urls" => %{"desktop" => %{"page" => "https://en.wikipedia.org/wiki/Test"}},
            "description" => "English musician"
          }
        })

      result = Biography.build(artist_info)

      assert result.source == "Wikipedia"
      assert result.bio_html == "<p>A musician from England.</p>"
      assert result.summary_html == "A musician from England."
      assert result.url == "https://en.wikipedia.org/wiki/Test"
      assert result.description == "English musician"
    end

    test "returns nil when no Wikipedia data is present" do
      artist_info = artist_info_fixture(%{wikipedia_data: nil})

      assert Biography.build(artist_info) == nil
    end

    test "returns nil when Wikipedia data has no bio" do
      artist_info = artist_info_fixture(%{wikipedia_data: %{}})

      assert Biography.build(artist_info) == nil
    end
  end

  describe "render_bio/1" do
    test "renders bio with Last.fm link and no license" do
      bio =
        ~s(Some artist biography text. <a href="https://www.last.fm/music/Test">Read more on Last.fm</a>)

      result = Phoenix.HTML.safe_to_string(Biography.render_bio(bio))

      assert result =~ "Some artist biography text."
      assert result =~ "Read more on Last.fm"
    end

    test "renders bio with Last.fm link and license text" do
      bio =
        ~s(Some artist biography text. <a href="https://www.last.fm/music/Test">Read more on Last.fm</a>. User-contributed text is available under the Creative Commons License.)

      result = Phoenix.HTML.safe_to_string(Biography.render_bio(bio))

      assert result =~ "Some artist biography text."
      assert result =~ "Read more on Last.fm"
      assert result =~ "Creative Commons License"
    end

    test "renders plain text bio without Last.fm link" do
      bio = "Just a plain biography."

      result = Biography.render_bio(bio)

      assert Phoenix.HTML.safe_to_string(result) =~ "Just a plain biography."
    end
  end

  describe "remove_read_more_link/1" do
    test "strips Last.fm read more link from summary" do
      summary =
        ~s(Some summary text. <a href="https://www.last.fm/music/Test">Read more on Last.fm</a>.)

      result = Biography.remove_read_more_link(summary)

      assert Phoenix.HTML.safe_to_string(result) =~ "Some summary text."
      refute Phoenix.HTML.safe_to_string(result) =~ "Read more on Last.fm"
    end

    test "returns content as-is when no Last.fm link present" do
      summary = "A summary without links."

      result = Biography.remove_read_more_link(summary)

      assert Phoenix.HTML.safe_to_string(result) =~ "A summary without links."
    end
  end
end
