defmodule MusicLibrary.ArtistsTest do
  use MusicLibrary.DataCase

  alias LastFm.APIMock
  alias MusicLibrary.Artists
  import MusicLibrary.Fixtures.Records
  import LastFm.Fixtures.Artist
  import Mox

  setup :verify_on_exit!

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

  describe "get_artist_info/1" do
    test "it returns the artist info" do
      collection_record =
        record_with_artist("Steven Wilson", %{
          title: "The Raven that refused to sing",
          purchased_at: DateTime.utc_now()
        })

      [artist] = collection_record.artists
      artist_musicbrainz_id = artist.musicbrainz_id

      expected_info = get_info()

      expect(APIMock, :get_artist_info, fn {:musicbrainz_id, ^artist_musicbrainz_id}, _config ->
        {:ok, expected_info}
      end)

      assert {:ok, expected_info} == Artists.get_artist_info(artist)
    end
  end
end
