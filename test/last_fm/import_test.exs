defmodule LastFm.ImportTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.ListeningStats

  @recent_tracks_fixture Path.expand(
                           "../support/fixtures/last_fm/user.getrecenttracks.json",
                           __DIR__
                         )

  describe "batch/1" do
    test "fetches recent tracks and persists them via ListeningStats" do
      response = @recent_tracks_fixture |> File.read!() |> JSON.decode!()

      Req.Test.stub(LastFm.API, fn conn ->
        assert URI.decode_query(conn.query_string)["method"] == "user.getrecenttracks"

        Req.Test.json(conn, response)
      end)

      assert {:ok, count} = LastFm.Import.batch([])
      assert count > 0
      assert ListeningStats.scrobble_count() == count
    end

    test "forwards limit and to_uts options to the Last.fm API" do
      response = @recent_tracks_fixture |> File.read!() |> JSON.decode!()

      Req.Test.stub(LastFm.API, fn conn ->
        params = URI.decode_query(conn.query_string)
        assert params["limit"] == "50"
        assert params["to"] == "1730600000"

        Req.Test.json(conn, response)
      end)

      assert {:ok, _count} = LastFm.Import.batch(limit: 50, to_uts: 1_730_600_000)
    end

    @tag :capture_log
    test "returns {:error, reason} when the Last.fm API fails" do
      Req.Test.stub(LastFm.API, fn conn ->
        Req.Test.json(conn, %{"error" => 10, "message" => "Invalid API key"})
      end)

      assert {:error, :invalid_api_key} = LastFm.Import.batch([])
      assert ListeningStats.scrobble_count() == 0
    end
  end
end
