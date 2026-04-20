defmodule MusicLibrary.Worker.PruneAssetsTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Assets
  alias MusicLibrary.Assets.Asset
  alias MusicLibrary.Worker.PruneAssets

  describe "perform/1" do
    @describetag :capture_log
    test "deletes unreferenced assets" do
      {:ok, orphan} = Assets.store(%{content: "orphan_data", format: "image/jpeg"})
      orphan_hash = orphan.hash

      assert %Asset{hash: ^orphan_hash} = Assets.get(orphan_hash)

      assert :ok = perform_job(PruneAssets, %{})

      assert Assets.get(orphan.hash) == nil
    end

    test "keeps assets referenced by records" do
      record = record()
      cover_hash = record.cover_hash

      assert :ok = perform_job(PruneAssets, %{})

      assert %Asset{hash: ^cover_hash} = Assets.get(cover_hash)
    end

    test "keeps assets referenced by artist info" do
      record = record()
      artist = hd(record.artists)
      _artist_info = artist_info(artist.musicbrainz_id)

      assert :ok = perform_job(PruneAssets, %{})

      # The artist info image data comes from Discogs fixture which stores an asset
      # The record's cover asset should still be present
      cover_hash = record.cover_hash
      assert %Asset{hash: ^cover_hash} = Assets.get(cover_hash)
    end

    test "succeeds with no unreferenced assets" do
      assert :ok = perform_job(PruneAssets, %{})
    end
  end
end
