defmodule MusicLibrary.Worker.BulkCronWorkersTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Worker.ArtistRefreshAllDiscogsData
  alias MusicLibrary.Worker.ArtistRefreshAllMusicBrainzData
  alias MusicLibrary.Worker.ArtistRefreshAllWikipediaData
  alias MusicLibrary.Worker.RecordGenerateAllEmbeddings
  alias MusicLibrary.Worker.RecordRefreshAllMusicBrainzData

  describe "RecordRefreshAllMusicBrainzData" do
    test "enqueues per-record MusicBrainz refresh jobs" do
      rec = record()

      assert {:ok, []} = perform_job(RecordRefreshAllMusicBrainzData, %{})

      assert_enqueued worker: MusicLibrary.Worker.RecordRefreshMusicBrainzData,
                      args: %{id: rec.id}
    end
  end

  describe "RecordGenerateAllEmbeddings" do
    test "enqueues per-record embedding generation jobs" do
      rec = record()

      assert {:ok, []} = perform_job(RecordGenerateAllEmbeddings, %{})

      assert_enqueued worker: MusicLibrary.Worker.GenerateRecordEmbedding,
                      args: %{record_id: rec.id}
    end
  end

  describe "ArtistRefreshAllMusicBrainzData" do
    test "enqueues per-artist MusicBrainz refresh jobs" do
      rec = record()
      artist = hd(rec.artists)
      info = artist_info(artist.musicbrainz_id)

      assert {:ok, []} = perform_job(ArtistRefreshAllMusicBrainzData, %{})

      assert_enqueued worker: MusicLibrary.Worker.ArtistRefreshMusicBrainzData,
                      args: %{id: info.id}
    end
  end

  describe "ArtistRefreshAllDiscogsData" do
    test "enqueues per-artist Discogs refresh jobs" do
      rec = record()
      artist = hd(rec.artists)
      info = artist_info(artist.musicbrainz_id)

      assert {:ok, []} = perform_job(ArtistRefreshAllDiscogsData, %{})

      assert_enqueued worker: MusicLibrary.Worker.ArtistRefreshDiscogsData,
                      args: %{id: info.id}
    end
  end

  describe "ArtistRefreshAllWikipediaData" do
    test "enqueues per-artist Wikipedia refresh jobs" do
      rec = record()
      artist = hd(rec.artists)
      info = artist_info(artist.musicbrainz_id)

      assert {:ok, []} = perform_job(ArtistRefreshAllWikipediaData, %{})

      assert_enqueued worker: MusicLibrary.Worker.ArtistRefreshWikipediaData,
                      args: %{id: info.id}
    end
  end
end
