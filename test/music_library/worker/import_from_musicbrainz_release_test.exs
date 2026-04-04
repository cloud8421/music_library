defmodule MusicLibrary.Worker.ImportFromMusicbrainzReleaseTest do
  use MusicLibrary.DataCase

  import MusicBrainz.Fixtures.Release
  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records.Record
  alias MusicLibrary.Worker.ImportFromMusicbrainzRelease

  describe "perform/1" do
    test "imports a record from a MusicBrainz release" do
      release_data = release(:marbles)
      release_id = release_id(:marbles)

      release_group_data = release_group(:marbles)
      release_group_id = release_group_id(:marbles)
      release_group_releases_data = release_group_releases(:marbles)

      cover_data = marbles_cover_data()

      Req.Test.stub(MusicBrainz.API, fn conn ->
        case conn.path_info do
          [_ws, _version, "release-group", ^release_group_id] ->
            Req.Test.json(conn, release_group_data)

          [_ws, _version, "release", ^release_id] ->
            Req.Test.json(conn, release_data)

          [_ws, _version, "release"] ->
            Req.Test.json(conn, release_group_releases_data)

          [_release_group, ^release_group_id, "front"] ->
            Plug.Conn.send_resp(conn, 200, cover_data)
        end
      end)

      purchased_at = DateTime.utc_now()

      assert :ok =
               perform_job(ImportFromMusicbrainzRelease, %{
                 "release_id" => release_id,
                 "format" => "cd",
                 "purchased_at" => DateTime.to_iso8601(purchased_at),
                 "selected_release_id" => release_id
               })

      imported_record = Repo.get_by!(Record, musicbrainz_id: release_group_id)
      assert imported_record.title == "Marbles"
      assert imported_record.purchased_at == DateTime.truncate(purchased_at, :second)
    end

    test "returns error on transport failure" do
      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, %Req.TransportError{reason: :timeout}} =
               perform_job(ImportFromMusicbrainzRelease, %{
                 "release_id" => "nonexistent-release-id",
                 "format" => "cd",
                 "purchased_at" => DateTime.to_iso8601(DateTime.utc_now()),
                 "selected_release_id" => "nonexistent-release-id"
               })
    end
  end
end
