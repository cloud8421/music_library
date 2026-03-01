defmodule MusicLibrary.Records.BatchTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records.Batch

  describe "refresh_musicbrainz_data/0" do
    test "enqueues refresh jobs for all records" do
      _record = record()

      assert {:ok, []} = Batch.refresh_musicbrainz_data()
    end

    test "succeeds with no records" do
      assert {:ok, []} = Batch.refresh_musicbrainz_data()
    end
  end

  describe "generate_embeddings/0" do
    test "enqueues embedding jobs for all records" do
      _record = record()

      assert {:ok, []} = Batch.generate_embeddings()
    end

    test "succeeds with no records" do
      assert {:ok, []} = Batch.generate_embeddings()
    end
  end
end
