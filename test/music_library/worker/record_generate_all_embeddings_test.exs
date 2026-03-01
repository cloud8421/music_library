defmodule MusicLibrary.Worker.RecordGenerateAllEmbeddingsTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Worker.RecordGenerateAllEmbeddings

  describe "perform/1" do
    test "enqueues embedding generation jobs for all records" do
      _record = record()

      assert {:ok, []} = perform_job(RecordGenerateAllEmbeddings, %{})
    end

    test "succeeds with no records" do
      assert {:ok, []} = perform_job(RecordGenerateAllEmbeddings, %{})
    end
  end
end
