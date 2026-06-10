defmodule MusicLibrary.Worker.ImportFromMusicbrainzReleaseTest do
  use MusicLibrary.DataCase

  import MusicBrainz.Fixtures.Release
  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicLibrary.Fixtures.Records

  alias Ecto.Adapters.SQL
  alias MusicLibrary.Records
  alias MusicLibrary.Records.Record
  alias MusicLibrary.Worker.ImportFromMusicbrainzRelease

  describe "unique constraint" do
    test "deduplicates enqueue for the same release_id" do
      args = %{
        "release_id" => release_id(:marbles),
        "format" => "cd",
        "purchased_at" => DateTime.to_iso8601(DateTime.utc_now()),
        "selected_release_id" => release_id(:marbles)
      }

      assert {:ok, first_job} = ImportFromMusicbrainzRelease.new(args) |> Oban.insert()

      # Second insert with the same unique keys returns the existing job
      assert {:ok, %Oban.Job{conflict?: true} = second_job} =
               ImportFromMusicbrainzRelease.new(args) |> Oban.insert()

      assert second_job.id == first_job.id
    end
  end

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

    test "broadcasts index_changed after successful import" do
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

      Records.subscribe_to_index()

      assert :ok =
               perform_job(ImportFromMusicbrainzRelease, %{
                 "release_id" => release_id,
                 "format" => "cd",
                 "purchased_at" => DateTime.to_iso8601(DateTime.utc_now()),
                 "selected_release_id" => release_id
               })

      assert_received :records_index_changed
    end

    test "cancels job when the record insert fails with a changeset error" do
      # Temporarily add the unique index that the record changeset's
      # unique_constraint references. The index was removed from the
      # production schema (20250226105533), but the clause exists as a
      # safety net.
      SQL.query!(
        Repo,
        "CREATE UNIQUE INDEX records_musicbrainz_id_format_index ON records(musicbrainz_id, format)"
      )

      on_exit(fn ->
        SQL.query!(
          Repo,
          "DROP INDEX IF EXISTS records_musicbrainz_id_format_index"
        )
      end)

      release_id = release_id(:marbles)
      release_group_id = release_group_id(:marbles)

      release_data = release(:marbles)
      release_group_data = release_group(:marbles)
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

      # Pre-create a record with matching musicbrainz_id and format so
      # the second import hits the unique constraint (musicbrainz_id, format).
      record(%{musicbrainz_id: release_group_id, format: "cd"})

      assert {:cancel, :already_imported} =
               perform_job(ImportFromMusicbrainzRelease, %{
                 "release_id" => release_id,
                 "format" => "cd",
                 "purchased_at" => DateTime.to_iso8601(DateTime.utc_now()),
                 "selected_release_id" => release_id
               })
    end
  end
end
