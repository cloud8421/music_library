defmodule MusicLibrary.Worker.RefreshScrobblesTest do
  use MusicLibrary.DataCase

  alias LastFm.Fixtures.RecentTracks
  alias MusicLibrary.Worker.RefreshScrobbles

  describe "perform/1" do
    test "fetches recent tracks and persists them" do
      Req.Test.stub(LastFm.API, fn conn ->
        Req.Test.json(conn, RecentTracks.get())
      end)

      assert :ok = perform_job(RefreshScrobbles, %{})
    end

    test "snoozes on retryable Last.fm error" do
      Req.Test.stub(LastFm.API, fn conn ->
        Req.Test.json(conn, %{"error" => 29, "message" => "Rate limit exceeded"})
      end)

      assert {:snooze, 60} = perform_job(RefreshScrobbles, %{})
    end

    test "cancels on permanent Last.fm error" do
      Req.Test.stub(LastFm.API, fn conn ->
        Req.Test.json(conn, %{"error" => 9, "message" => "Invalid session key"})
      end)

      assert {:cancel, _reason} = perform_job(RefreshScrobbles, %{})
    end
  end
end
