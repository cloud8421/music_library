defmodule MusicLibrary.Records.EnrichmentTest do
  use MusicLibrary.DataCase

  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Assets
  alias MusicLibrary.Records.Enrichment

  describe "refresh_musicbrainz_data/1" do
    test "updates release_ids, included_release_group_ids, and artists" do
      release_group_id = release_group_id(:marbles)

      record =
        record(
          musicbrainz_id: release_group_id,
          musicbrainz_data: Map.put(release_group(:marbles), "releases", [])
        )

      assert record.release_ids == []
      assert record.included_release_group_ids == []

      new_release_group = release_group(:lockdown_trilogy)
      new_release_group_releases = release_group_releases(:lockdown_trilogy)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        case conn.path_info do
          [_ws, _version, "release-group", ^release_group_id] ->
            Req.Test.json(conn, new_release_group)

          [_ws, _version, "release"] ->
            Req.Test.json(conn, new_release_group_releases)
        end
      end)

      {:ok, updated_record} = Enrichment.refresh_musicbrainz_data(record)

      assert record.release_ids !== updated_record.release_ids
      assert record.included_release_group_ids !== updated_record.included_release_group_ids
      assert record.artists !== updated_record.artists
      assert updated_record.artists !== []
    end
  end

  describe "refresh_cover/1" do
    test "fetches and stores the updated cover" do
      record = record(cover_data: marbles_cover_data())

      raven_cover_data = raven_cover_data()

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Plug.Conn.send_resp(conn, 200, raven_cover_data)
      end)

      assert {:ok, updated_record} = Enrichment.refresh_cover(record)

      assert updated_record.cover_hash ==
               "6E0D25D1FD1019D771D7EB3F777E2C7C1B06A73A92E56A584D674D86DD8AF441"

      {:ok, expected_content} = Assets.Image.resize(raven_cover_data())

      assert Assets.get(updated_record.cover_hash).content == expected_content
    end
  end

  describe "populate_genres/1" do
    test "updates record genres from OpenAI response" do
      record = record(%{genres: []})
      genres = ["progressive rock", "art rock", "symphonic rock"]

      Req.Test.stub(OpenAI.API, fn conn ->
        Req.Test.json(conn, %{
          "output" => [
            %{
              "type" => "message",
              "role" => "assistant",
              "content" => [
                %{"type" => "output_text", "text" => JSON.encode!(%{"genres" => genres})}
              ]
            }
          ]
        })
      end)

      assert {:ok, updated} = Enrichment.populate_genres(record)
      assert updated.genres == genres
    end

    @tag :capture_log
    test "returns error tuple when OpenAI API fails" do
      record = record(%{genres: []})

      Req.Test.stub(OpenAI.API, fn conn ->
        Plug.Conn.send_resp(
          conn,
          500,
          JSON.encode!(%{"error" => %{"message" => "internal server error"}})
        )
      end)

      assert {:error, %OpenAI.API.ErrorResponse{status: 500, kind: :server_error}} =
               Enrichment.populate_genres(record)
    end
  end
end
