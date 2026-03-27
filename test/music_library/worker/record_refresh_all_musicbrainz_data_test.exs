defmodule MusicLibrary.Worker.RecordRefreshAllMusicBrainzDataTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Worker.RecordRefreshAllMusicBrainzData

  describe "perform/1" do
    test "enqueues refresh jobs for all records" do
      record = record()

      assert {:ok, []} = perform_job(RecordRefreshAllMusicBrainzData, %{})

      assert_enqueued worker: MusicLibrary.Worker.RecordRefreshMusicBrainzData,
                      args: %{id: record.id}
    end
  end
end
