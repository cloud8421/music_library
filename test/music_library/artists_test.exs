defmodule MusicLibrary.ArtistsTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Artists
  import MusicLibrary.Fixtures.Records

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

  describe "fetch_artist_info/1" do
    test "it stores musicbrainz and discogs data" do
      steven_wilson_musicbrainz_id = "3a51b862-0144-40f6-aa17-6aaeefea29d9"

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, MusicBrainz.Fixtures.Artist.get_artist())
      end)

      Req.Test.stub(Discogs.API, fn conn ->
        Req.Test.json(conn, Discogs.Fixtures.Artist.get_artist())
      end)

      assert {:ok, artist_info} = Artists.fetch_artist_info(steven_wilson_musicbrainz_id)

      assert artist_info.id == steven_wilson_musicbrainz_id
      assert artist_info.musicbrainz_data == MusicBrainz.Fixtures.Artist.get_artist()
      assert artist_info.discogs_data == Discogs.Fixtures.Artist.get_artist()
    end
  end
end
