defmodule MusicLibrary.Worker.ArtistRefreshAllWikipediaDataTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Worker.ArtistRefreshAllWikipediaData

  describe "perform/1" do
    test "enqueues refresh jobs for all artist infos" do
      record = record()
      artist = hd(record.artists)
      _artist_info = artist_info(artist.musicbrainz_id)

      assert {:ok, []} = perform_job(ArtistRefreshAllWikipediaData, %{})
    end

    test "succeeds with no artist infos" do
      assert {:ok, []} = perform_job(ArtistRefreshAllWikipediaData, %{})
    end
  end
end
