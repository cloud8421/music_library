defmodule MusicLibrary.Worker.RecordGenerateAllEmbeddingsTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Worker.RecordGenerateAllEmbeddings

  describe "perform/1" do
    test "enqueues embedding generation jobs for all records" do
      record = record()

      assert {:ok, []} = perform_job(RecordGenerateAllEmbeddings, %{})

      assert_enqueued worker: MusicLibrary.Worker.GenerateRecordEmbedding,
                      args: %{record_id: record.id}
    end
  end
end
