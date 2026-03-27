defmodule MusicBrainz.ReleaseTest do
  use ExUnit.Case, async: true

  alias MusicBrainz.{Fixtures, Release}

  describe "release_duration/1" do
    test "returns the total milliseconds" do
      release =
        Fixtures.Release.release_with_media(:marbles)
        |> Release.from_api_response()

      assert Release.release_duration(release) == 5_933_595
    end

    test "handles empty durations" do
      release =
        Fixtures.Release.release_with_media(:marbles)
        |> put_in(["media", Access.all(), "tracks", Access.all(), "length"], nil)
        |> Release.from_api_response()

      assert Release.release_duration(release) == 0
    end
  end
end
