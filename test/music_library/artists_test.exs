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

  describe "get_all_artist_ids/0" do
    test "it returns unique artist IDs" do
      marillion_record = record_with_artist("Marillion")
      _another_marillion_record = record_with_artist("Marillion")
      steven_wilson_record = record_with_artist("Steven Wilson")

      [marillion] = marillion_record.artists
      [steven_wilson] = steven_wilson_record.artists

      expected = MapSet.new([marillion.musicbrainz_id, steven_wilson.musicbrainz_id])

      assert expected == Artists.get_all_artist_ids()
    end
  end
end
