defmodule MusicLibrary.Artists.BatchTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Artists.Batch

  setup do
    record = record()
    artist = hd(record.artists)
    artist_info = artist_info(artist.musicbrainz_id)
    %{artist_info: artist_info}
  end

  describe "refresh_musicbrainz_data/0" do
    test "enqueues refresh jobs for all artist infos", %{artist_info: artist_info} do
      assert {:ok, []} = Batch.refresh_musicbrainz_data()

      assert_enqueued worker: MusicLibrary.Worker.ArtistRefreshMusicBrainzData,
                      args: %{id: artist_info.id}
    end
  end

  describe "refresh_discogs_data/0" do
    test "enqueues refresh jobs for all artist infos", %{artist_info: artist_info} do
      assert {:ok, []} = Batch.refresh_discogs_data()

      assert_enqueued worker: MusicLibrary.Worker.ArtistRefreshDiscogsData,
                      args: %{id: artist_info.id}
    end
  end

  describe "refresh_wikipedia_data/0" do
    test "enqueues refresh jobs for all artist infos", %{artist_info: artist_info} do
      assert {:ok, []} = Batch.refresh_wikipedia_data()

      assert_enqueued worker: MusicLibrary.Worker.ArtistRefreshWikipediaData,
                      args: %{id: artist_info.id}
    end
  end

  describe "refresh_lastfm_data/0" do
    test "enqueues refresh jobs for all artist infos", %{artist_info: artist_info} do
      assert {:ok, []} = Batch.refresh_lastfm_data()

      assert_enqueued worker: MusicLibrary.Worker.FetchArtistLastFmData,
                      args: %{id: artist_info.id}
    end
  end
end
