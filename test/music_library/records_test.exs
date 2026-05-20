defmodule MusicLibrary.RecordsTest do
  use MusicLibrary.DataCase

  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicLibrary.ColorHelpers, only: [color_hex?: 1]
  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records

  describe "create_record/1" do
    test "populates computed values" do
      record =
        record(musicbrainz_data: release_group(:lockdown_trilogy))

      assert record.release_ids == ["77e746fc-566f-445b-a62b-cc014280fac9"]

      assert record.included_release_group_ids == [
               "749c07b5-4900-404b-bea9-bb6b16fa991e",
               "61077431-0057-4119-8f06-0df1098d21e5",
               "c36123e3-8899-48a5-8196-9dbb72421d69",
               "d463f2b1-d254-4baf-a957-fb78c6e5b956"
             ]

      assert record.cover_hash ==
               "599407DDF69907D4A60FE13CCAA824D25CF08DC124FD6AA3E8E7ECD98C885FFE"

      assert length(record.dominant_colors) == 5
      assert Enum.all?(record.dominant_colors, &color_hex?/1)
    end

    @tag :capture_log
    test "succeeds when color extraction fails" do
      record = record(dominant_colors: [], cover_hash: "nonexistent_hash")

      assert record.dominant_colors == []
    end

    test "queues a task to retrieve artist info data" do
      record =
        record(musicbrainz_data: release_group(:lockdown_trilogy))

      [artist] = record.artists

      assert_enqueued worker: MusicLibrary.Worker.FetchArtistInfo,
                      args: %{id: artist.musicbrainz_id}
    end
  end

  describe "update_record/2" do
    test "queues a task to retrieve artist info data" do
      record =
        record(musicbrainz_data: release_group(:lockdown_trilogy))

      [artist] = record.artists

      Oban.drain_queue(queue: :default)

      Records.update_record(record, %{title: "Updated Title"})

      assert_enqueued worker: MusicLibrary.Worker.FetchArtistInfo,
                      args: %{id: artist.musicbrainz_id}
    end
  end

  describe "delete_record/1" do
    test "queues a task to delete artist info data" do
      record =
        record(musicbrainz_data: release_group(:lockdown_trilogy))

      [artist] = record.artists

      assert {:ok, deleted} = Records.delete_record(record)
      assert deleted.id == record.id

      assert_raise Ecto.NoResultsError, fn ->
        Records.get_record!(record.id)
      end

      assert_enqueued worker: MusicLibrary.Worker.PruneArtistInfo,
                      args: %{id: artist.musicbrainz_id}
    end
  end

  describe "get_record!/1" do
    test "fetches the record by id" do
      expected = record()

      assert expected == Records.get_record!(expected.id)
    end
  end

  describe "broadcast_index_changed/0 and subscribe_to_index/0" do
    test "broadcasts :records_index_changed to subscribers" do
      Records.subscribe_to_index()
      Records.broadcast_index_changed()

      assert_received :records_index_changed
    end
  end
end
