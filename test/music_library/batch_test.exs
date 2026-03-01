defmodule MusicLibrary.BatchTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Batch
  alias MusicLibrary.Records.Record

  describe "run_on_all/3" do
    test "processes all records and returns empty list on success" do
      _r1 = record()
      _r2 = record()

      assert {:ok, []} =
               Batch.run_on_all(Record, "record", fn _record ->
                 :ok
               end)
    end

    @tag :capture_log
    test "collects failed record IDs" do
      r1 = record()
      r2 = record()

      assert {:ok, failed_ids} =
               Batch.run_on_all(Record, "record", fn _record ->
                 {:error, :test_failure}
               end)

      assert length(failed_ids) == 2
      assert r1.id in failed_ids
      assert r2.id in failed_ids
    end

    @tag :capture_log
    test "handles mixed success and failure" do
      r1 = record()
      _r2 = record()

      assert {:ok, failed_ids} =
               Batch.run_on_all(Record, "record", fn record ->
                 if record.id == r1.id do
                   {:error, :test_failure}
                 else
                   :ok
                 end
               end)

      assert failed_ids == [r1.id]
    end

    test "works with empty table" do
      assert {:ok, []} =
               Batch.run_on_all(Record, "record", fn _record ->
                 :ok
               end)
    end

    test "accepts {:ok, result} as success" do
      _r1 = record()

      assert {:ok, []} =
               Batch.run_on_all(Record, "record", fn _record ->
                 {:ok, :updated}
               end)
    end
  end
end
