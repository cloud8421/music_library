defmodule MusicLibrary.Worker.RecordRefreshAllMusicBrainzDataTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Worker.RecordRefreshAllMusicBrainzData

  describe "perform/1" do
    test "enqueues refresh jobs for all records" do
      _record = record()

      assert {:ok, []} = perform_job(RecordRefreshAllMusicBrainzData, %{})
    end

    test "succeeds with no records" do
      assert {:ok, []} = perform_job(RecordRefreshAllMusicBrainzData, %{})
    end
  end
end
