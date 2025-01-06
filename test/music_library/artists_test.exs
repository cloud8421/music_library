defmodule MusicLibrary.ArtistsTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Artists
  import MusicLibrary.RecordsFixtures

  describe "get_artist/1" do
    test "it returns records with essential data" do
      record = record()
      [expected] = record.artists

      artist = Artists.get_artist!(expected.musicbrainz_id)

      assert expected == artist
    end
  end
end
