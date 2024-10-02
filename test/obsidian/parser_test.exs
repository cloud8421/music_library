defmodule Obsidian.ParserTest do
  use ExUnit.Case, async: true
  alias Obsidian.{Entry, Parser}

  @marbles_entry_path Path.expand("../support/fixtures/marillion-marbles.md", __DIR__)
  @guardians_entry_path Path.expand("../support/fixtures/guardians.md", __DIR__)

  test "parses the content of the Obsidian album entry" do
    entry_contents = File.read!(@marbles_entry_path)

    assert Parser.from_file_contents(entry_contents) ==
             {:ok,
              %Entry{
                type: :album,
                musicbrainz_id: "20790e26-98e4-3ad3-a67f-b674758b942d",
                title: "Marbles",
                release: "2004",
                image_url:
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
    entry_contents = File.read!(@guardians_entry_path)

    assert Parser.from_file_contents(entry_contents) ==
             {:ok,
              %Entry{
                genres: ["classic rock", "pop", "pop rock", "rock"],
                image_url:
                  "https://coverartarchive.org/release-group/950092d6-45f6-4269-87da-99a9ff2fcc52/front",
                musicbrainz_id: "950092d6-45f6-4269-87da-99a9ff2fcc52",
                title: "Guardians of the Galaxy: Awesome Mix, Vol. 1",
                type: :album,
                release: "2014"
              }}
  end
end
