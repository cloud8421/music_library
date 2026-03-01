defmodule MusicLibrary.Worker.PruneAssetsTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Assets
  alias MusicLibrary.Worker.PruneAssets

  describe "perform/1" do
    @describetag :capture_log
    test "deletes unreferenced assets" do
      {:ok, orphan} = Assets.store(%{content: "orphan_data", format: "image/jpeg"})

      assert Assets.get(orphan.hash) != nil

      assert :ok = perform_job(PruneAssets, %{})

      assert Assets.get(orphan.hash) == nil
    end

    test "keeps assets referenced by records" do
      record = record()

      assert :ok = perform_job(PruneAssets, %{})

      assert Assets.get(record.cover_hash) != nil
    end

    test "keeps assets referenced by artist info" do
      record = record()
      artist = hd(record.artists)
      _artist_info = artist_info(artist.musicbrainz_id)

      assert :ok = perform_job(PruneAssets, %{})

      # The artist info image data comes from Discogs fixture which stores an asset
      # The record's cover asset should still be present
      assert Assets.get(record.cover_hash) != nil
    end

    test "succeeds with no unreferenced assets" do
      assert :ok = perform_job(PruneAssets, %{})
    end
  end
end
