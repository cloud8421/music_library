defmodule MusicLibrary.Records.ParserTest do
  use ExUnit.Case, async: true
  alias MusicLibrary.Records.Parser

  @obsidian_entry_path Path.expand("../../support/fixtures/marillion-marbles.md", __DIR__)

  test "parses the content of the Obsidian album entry" do
    entry_contents = File.read!(@obsidian_entry_path)

    assert Parser.from_entry_contents(entry_contents) ==
             {:ok,
              %{
                type: :album,
                musicbrainz_id: "20790e26-98e4-3ad3-a67f-b674758b942d",
                title: "Marbles",
                year: 2004,
                image:
                  "https://coverartarchive.org/release-group/20790e26-98e4-3ad3-a67f-b674758b942d/front",
                genres: [
                  "alternative rock",
                  "art rock",
                  "baroque pop",
                  "pop rock",
                  "progressive rock",
                  "psychedelic pop",
                  "rock"
                ]
              }}
  end

  test "handles special characters in titles" do
    entry_contents = """
    ---
    type: "musicRelease"
    subType: "Album"
    title: "Guardians of the Galaxy: Awesome Mix, Vol. 1"
    englishTitle: "Guardians of the Galaxy: Awesome Mix, Vol. 1"
    year: "2014"
    dataSource: "MusicBrainz API"
    url: "https://musicbrainz.org/release-group/950092d6-45f6-4269-87da-99a9ff2fcc52"
    id: "950092d6-45f6-4269-87da-99a9ff2fcc52"
    genres:
      - "classic rock"
      - "pop"
      - "pop rock"
      - "rock"
    artists:
      - "Various Artists"
    image: "https://coverartarchive.org/release-group/950092d6-45f6-4269-87da-99a9ff2fcc52/front"
    rating: 9.6
    personalRating: 0
    tags: "mediaDB/music/Album"
    ---
    """

    assert Parser.from_entry_contents(entry_contents) ==
             {:ok,
              %{
                genres: ["classic rock", "pop", "pop rock", "rock"],
                image:
                  "https://coverartarchive.org/release-group/950092d6-45f6-4269-87da-99a9ff2fcc52/front",
                musicbrainz_id: "950092d6-45f6-4269-87da-99a9ff2fcc52",
                title: "Guardians of the Galaxy: Awesome Mix, Vol. 1",
                type: :album,
                year: 2014
              }}
  end
end
