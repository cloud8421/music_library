defmodule MusicLibrary.Records.ParserTest do
  use ExUnit.Case, async: true
  alias MusicLibrary.Records.{Parser, Record}

  @obsidian_entry_path Path.expand("../../support/fixtures/marillion-marbles.md", __DIR__)

  test "parses the content of the Obsidian album entry" do
    entry_contents = File.read!(@obsidian_entry_path)

    assert Parser.from_entry_contents(entry_contents) ==
             {:ok,
              %Record{
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
end
