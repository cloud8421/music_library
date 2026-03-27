defmodule MusicLibrary.Worker.RecordRefreshMusicBrainzDataTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicBrainz.Fixtures.ReleaseGroup
  alias MusicLibrary.Records
  alias MusicLibrary.Worker.RecordRefreshMusicBrainzData

  describe "perform/1" do
    test "refreshes MusicBrainz data for a record" do
      record = record()

      Req.Test.stub(MusicBrainz.API, fn conn ->
        case conn.request_path do
          "/ws/2/release-group/" <> _ ->
            Req.Test.json(conn, ReleaseGroup.release_group(:marbles))

          "/ws/2/release" <> _ ->
            Req.Test.json(conn, %{"releases" => [], "release-count" => 0, "release-offset" => 0})
        end
      end)

      assert :ok = perform_job(RecordRefreshMusicBrainzData, %{"id" => record.id})

      updated = Records.get_record!(record.id)
      assert updated.musicbrainz_data["title"] == "Marbles"
    end

    test "raises when record does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        perform_job(RecordRefreshMusicBrainzData, %{"id" => Ecto.UUID.generate()})
      end
    end
  end
end
