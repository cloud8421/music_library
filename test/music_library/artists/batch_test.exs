defmodule MusicLibrary.Artists.BatchTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Artists.Batch

  setup do
    record = record()
    artist = hd(record.artists)
    _artist_info = artist_info(artist.musicbrainz_id)
    :ok
  end

  describe "refresh_musicbrainz_data/0" do
    test "enqueues refresh jobs for all artist infos" do
      assert {:ok, []} = Batch.refresh_musicbrainz_data()
    end
  end

  describe "refresh_discogs_data/0" do
    test "enqueues refresh jobs for all artist infos" do
      assert {:ok, []} = Batch.refresh_discogs_data()
    end
  end

  describe "refresh_wikipedia_data/0" do
    test "enqueues refresh jobs for all artist infos" do
      assert {:ok, []} = Batch.refresh_wikipedia_data()
    end
  end

  describe "refresh_lastfm_data/0" do
    test "enqueues refresh jobs for all artist infos" do
      assert {:ok, []} = Batch.refresh_lastfm_data()
    end
  end
end
