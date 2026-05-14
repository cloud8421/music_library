defmodule MusicLibrary.Worker.ImportFromMusicbrainzReleaseGroupTest do
  use MusicLibrary.DataCase, async: true

  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records
  alias MusicLibrary.Records.Record
  alias MusicLibrary.Worker.FetchArtistInfo
  alias MusicLibrary.Worker.ImportFromMusicbrainzReleaseGroup

  describe "perform/1" do
    test "imports a record from a MusicBrainz release group" do
      release_group_data = release_group(:marbles)
      release_group_id = release_group_id(:marbles)
      release_group_releases_data = release_group_releases(:marbles)

      cover_data = marbles_cover_data()

      Req.Test.stub(MusicBrainz.API, fn conn ->
        case conn.path_info do
          [_ws, _version, "release-group", ^release_group_id] ->
            Req.Test.json(conn, release_group_data)

          [_ws, _version, "release"] ->
            Req.Test.json(conn, release_group_releases_data)

          [_release_group, ^release_group_id, "front"] ->
            Plug.Conn.send_resp(conn, 200, cover_data)
        end
      end)

      purchased_at = DateTime.utc_now()

      assert :ok =
               perform_job(ImportFromMusicbrainzReleaseGroup, %{
                 "release_group_id" => release_group_id,
                 "format" => "cd",
                 "purchased_at" => DateTime.to_iso8601(purchased_at)
               })

      imported_record = Repo.get_by!(Record, musicbrainz_id: release_group_id)
      assert imported_record.title == "Marbles"
      assert imported_record.format == :cd
      assert imported_record.purchased_at == DateTime.truncate(purchased_at, :second)

      assert_enqueued(
        worker: FetchArtistInfo,
        args: %{"id" => "1932f5b6-0b7b-4050-b1df-833ca89e5f44"}
      )
    end

    test "imports a wishlist record when purchased_at is nil" do
      release_group_data = release_group(:marbles)
      release_group_id = release_group_id(:marbles)
      release_group_releases_data = release_group_releases(:marbles)

      cover_data = marbles_cover_data()

      Req.Test.stub(MusicBrainz.API, fn conn ->
        case conn.path_info do
          [_ws, _version, "release-group", ^release_group_id] ->
            Req.Test.json(conn, release_group_data)

          [_ws, _version, "release"] ->
            Req.Test.json(conn, release_group_releases_data)

          [_release_group, ^release_group_id, "front"] ->
            Plug.Conn.send_resp(conn, 200, cover_data)
        end
      end)

      assert :ok =
               perform_job(ImportFromMusicbrainzReleaseGroup, %{
                 "release_group_id" => release_group_id,
                 "format" => "vinyl",
                 "purchased_at" => nil
               })

      imported_record = Repo.get_by!(Record, musicbrainz_id: release_group_id)
      assert imported_record.purchased_at == nil
      assert imported_record.format == :vinyl
    end

    test "returns error on transport failure" do
      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, %Req.TransportError{reason: :timeout}} =
               perform_job(ImportFromMusicbrainzReleaseGroup, %{
                 "release_group_id" => "nonexistent-release-group-id",
                 "format" => "cd",
                 "purchased_at" => DateTime.to_iso8601(DateTime.utc_now())
               })
    end

    test "broadcasts index_changed after successful import" do
      release_group_data = release_group(:marbles)
      release_group_id = release_group_id(:marbles)
      release_group_releases_data = release_group_releases(:marbles)

      cover_data = marbles_cover_data()

      Req.Test.stub(MusicBrainz.API, fn conn ->
        case conn.path_info do
          [_ws, _version, "release-group", ^release_group_id] ->
            Req.Test.json(conn, release_group_data)

          [_ws, _version, "release"] ->
            Req.Test.json(conn, release_group_releases_data)

          [_release_group, ^release_group_id, "front"] ->
            Plug.Conn.send_resp(conn, 200, cover_data)
        end
      end)

      Records.subscribe_to_index()

      assert :ok =
               perform_job(ImportFromMusicbrainzReleaseGroup, %{
                 "release_group_id" => release_group_id,
                 "format" => "cd",
                 "purchased_at" => DateTime.to_iso8601(DateTime.utc_now())
               })

      assert_received :records_index_changed
    end
  end
end
