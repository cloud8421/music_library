defmodule MusicLibrary.Records.ImportTest do
  use MusicLibrary.DataCase

  import MusicBrainz.Fixtures.Release
  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records.Import

  describe "import_from_musicbrainz_release_group/2" do
    test "saves a record with its cover art" do
      current_time = DateTime.utc_now()

      release_group = release_group(:marbles)
      release_group_id = release_group_id(:marbles)
      release_group_releases = release_group_releases(:marbles)

      cover_data = marbles_cover_data()

      Req.Test.stub(MusicBrainz.API, fn conn ->
        case conn.path_info do
          [_ws, _version, "release-group", ^release_group_id] ->
            Req.Test.json(conn, release_group)

          [_ws, _version, "release"] ->
            Req.Test.json(conn, release_group_releases)

          [_release_group, ^release_group_id, "front"] ->
            Plug.Conn.send_resp(conn, 200, cover_data)
        end
      end)

      assert {:ok, record} =
               Import.import_from_musicbrainz_release_group(release_group_id,
                 format: :vinyl,
                 purchased_at: current_time
               )

      assert [artist] = record.artists
      assert artist.name == "Marillion"

      assert record.musicbrainz_id == release_group_id
      assert record.title == "Marbles"
      assert record.format == :vinyl
      assert record.purchased_at == DateTime.truncate(current_time, :second)

      assert record.release_ids ==
               [
                 "0e290154-5375-4f4f-a658-4a92bf02faa5",
                 "3f1cc80f-4507-48a9-899c-c1bda83280c2",
                 "d3f9b9e2-73f5-4b47-a2a7-2c2199aad608",
                 "2c4ecd84-7a84-4f42-a600-2f00ed8978c9",
                 "ab151aa6-7538-4e93-be60-eded52b5b7b7",
                 "b94bbd1f-ae5d-4e7b-98ff-28bfe135f20c",
                 "4b9fe13b-4837-4c02-9368-e97ba6f5a086",
                 "3f89357a-eeb3-4040-af34-a27b7c2aea2b",
                 "a4b02377-0b5e-448e-9cd6-5500c0378523",
                 "f3937bc5-b99f-443a-9609-a404201f21ca"
               ]
    end
  end

  describe "import_from_musicbrainz_release/2" do
    test "saves a record with its cover art" do
      current_time = DateTime.utc_now()

      release = release(:marbles)
      release_id = release_id(:marbles)

      release_group = release_group(:marbles)
      release_group_id = release_group_id(:marbles)
      release_group_releases = release_group_releases(:marbles)

      cover_data = marbles_cover_data()

      Req.Test.stub(MusicBrainz.API, fn conn ->
        case conn.path_info do
          [_ws, _version, "release-group", ^release_group_id] ->
            Req.Test.json(conn, release_group)

          [_ws, _version, "release", ^release_id] ->
            Req.Test.json(conn, release)

          [_ws, _version, "release"] ->
            Req.Test.json(conn, release_group_releases)

          [_release_group, ^release_group_id, "front"] ->
            Plug.Conn.send_resp(conn, 200, cover_data)
        end
      end)

      assert {:ok, record} =
               Import.import_from_musicbrainz_release(release_id,
                 format: :vinyl,
                 purchased_at: current_time
               )

      assert [artist] = record.artists
      assert artist.name == "Marillion"

      assert record.musicbrainz_id == release_group_id
      assert record.title == "Marbles"
      assert record.format == :vinyl
      assert record.purchased_at == DateTime.truncate(current_time, :second)

      assert record.release_ids ==
               [
                 "0e290154-5375-4f4f-a658-4a92bf02faa5",
                 "3f1cc80f-4507-48a9-899c-c1bda83280c2",
                 "d3f9b9e2-73f5-4b47-a2a7-2c2199aad608",
                 "2c4ecd84-7a84-4f42-a600-2f00ed8978c9",
                 "ab151aa6-7538-4e93-be60-eded52b5b7b7",
                 "b94bbd1f-ae5d-4e7b-98ff-28bfe135f20c",
                 "4b9fe13b-4837-4c02-9368-e97ba6f5a086",
                 "3f89357a-eeb3-4040-af34-a27b7c2aea2b",
                 "a4b02377-0b5e-448e-9cd6-5500c0378523",
                 "f3937bc5-b99f-443a-9609-a404201f21ca"
               ]
    end
  end

  describe "get_artist_records/1" do
    test "returns records with essential data" do
      expected = record()

      artist_musicbrainz_id = expected.artists |> hd() |> Map.get(:musicbrainz_id)

      [artist_record] = Import.get_artist_records(artist_musicbrainz_id)

      assert expected.id == artist_record.id
    end
  end
end
