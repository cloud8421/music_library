defmodule MusicLibrary.Records.BatchTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records.Batch

  describe "refresh_musicbrainz_data/0" do
    test "enqueues refresh jobs for all records" do
      record = record()

      assert {:ok, []} = Batch.refresh_musicbrainz_data()

      assert_enqueued worker: MusicLibrary.Worker.RecordRefreshMusicBrainzData,
                      args: %{id: record.id}
    end
  end

  describe "generate_embeddings/0" do
    test "enqueues embedding jobs for all records" do
      record = record()

      assert {:ok, []} = Batch.generate_embeddings()

      assert_enqueued(
        worker: MusicLibrary.Worker.GenerateRecordEmbedding,
        args: %{record_id: record.id}
      )
    end
  end
end
