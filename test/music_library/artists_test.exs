defmodule MusicLibrary.ArtistsTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Artists

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

  describe "search_by_name/2" do
    test "returns artists matching the query" do
      record = record_with_artist("Marillion")
      [artist] = record.artists
      artist_info(artist.musicbrainz_id)

      results = Artists.search_by_name("Marillion", 10)

      assert length(results) == 1
      assert hd(results).artist.name == "Marillion"
    end

    test "returns empty list for empty query" do
      assert Artists.search_by_name("", 10) == []
      assert Artists.search_by_name("   ", 10) == []
    end

    test "respects limit" do
      for name <- ["Marillion", "Steven Wilson"] do
        record = record_with_artist(name)
        [artist] = record.artists
        artist_info(artist.musicbrainz_id)
      end

      results = Artists.search_by_name("i", 1)

      assert length(results) == 1
    end
  end

  describe "search_by_name_count/1" do
    test "returns count of matching artists" do
      record = record_with_artist("Marillion")
      _other = record_with_artist("Marillion")

      [artist] = record.artists
      artist_info(artist.musicbrainz_id)

      assert Artists.search_by_name_count("Marillion") == 1
    end

    test "returns 0 for empty query" do
      assert Artists.search_by_name_count("") == 0
      assert Artists.search_by_name_count("   ") == 0
    end

    test "returns 0 for no matches" do
      assert Artists.search_by_name_count("zzz_nonexistent_zzz") == 0
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
