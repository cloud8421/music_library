defmodule MusicLibrary.ScrobbleActivityTest do
  @moduledoc false

  use MusicLibrary.DataCase

  alias MusicBrainz.Fixtures.Release, as: ReleaseFixtures
  alias MusicBrainz.Release
  alias MusicBrainz.Release.{Artist, Medium, Track}
  alias MusicLibrary.ScrobbleActivity
  alias MusicLibrary.Secrets

  @release ReleaseFixtures.release_with_media(:marbles) |> Release.from_api_response()

  defp store_session_key(_) do
    Secrets.store("last_fm_session_key", "test_session_key")
    :ok
  end

  defp stub_lastfm_success(_) do
    Req.Test.stub(LastFm.API, fn conn ->
      Req.Test.json(conn, %{"scrobbles" => %{"@attr" => %{"accepted" => 1}}})
    end)

    :ok
  end

  describe "can_scrobble?/0" do
    test "returns false when no session key is stored" do
      refute ScrobbleActivity.can_scrobble?()
    end

    test "returns true when session key exists" do
      Secrets.store("last_fm_session_key", "test_session_key")
      assert ScrobbleActivity.can_scrobble?()
    end
  end

  describe "scrobble_release/3" do
    setup [:store_session_key, :stub_lastfm_success]

    test "scrobbles all tracks with :started_at" do
      started_at = DateTime.utc_now()
      assert {:ok, _} = ScrobbleActivity.scrobble_release(@release, :started_at, started_at)
    end

    test "scrobbles all tracks with :finished_at" do
      finished_at = DateTime.utc_now()
      assert {:ok, _} = ScrobbleActivity.scrobble_release(@release, :finished_at, finished_at)
    end

    test "returns error when release has zero duration" do
      zero_duration_release = %{@release | media: [%{tracks: [%{length: 0}]}]}
      started_at = DateTime.utc_now()

      assert {:error, :no_duration} =
               ScrobbleActivity.scrobble_release(zero_duration_release, :started_at, started_at)
    end
  end

  describe "scrobble_release/3 without session key" do
    setup [:stub_lastfm_success]

    test "returns error" do
      started_at = DateTime.utc_now()

      assert {:error, :no_session_key} =
               ScrobbleActivity.scrobble_release(@release, :started_at, started_at)
    end
  end

  describe "scrobble_medium/4" do
    setup [:store_session_key, :stub_lastfm_success]

    test "scrobbles tracks from a specific medium with :started_at" do
      started_at = DateTime.utc_now()
      assert {:ok, _} = ScrobbleActivity.scrobble_medium(1, @release, :started_at, started_at)
    end

    test "scrobbles tracks from a specific medium with :finished_at" do
      finished_at = DateTime.utc_now()
      assert {:ok, _} = ScrobbleActivity.scrobble_medium(1, @release, :finished_at, finished_at)
    end

    test "returns error when medium not found" do
      started_at = DateTime.utc_now()

      assert {:error, :medium_not_found} =
               ScrobbleActivity.scrobble_medium(99, @release, :started_at, started_at)
    end

    test "returns error when medium not found with :finished_at" do
      finished_at = DateTime.utc_now()

      assert {:error, :medium_not_found} =
               ScrobbleActivity.scrobble_medium(99, @release, :finished_at, finished_at)
    end

    test "returns error when medium has zero duration" do
      zero_duration_medium = %Medium{
        title: "",
        format: "CD",
        number: 1,
        track_count: 1,
        tracks: [
          %Track{id: "t1", title: "Silent", length: 0, artists: [], number: "1", position: 1}
        ]
      }

      release = %{@release | media: [zero_duration_medium]}
      started_at = DateTime.utc_now()

      assert {:error, :no_duration} =
               ScrobbleActivity.scrobble_medium(1, release, :started_at, started_at)
    end
  end

  describe "scrobble_medium/4 without session key" do
    setup [:stub_lastfm_success]

    test "returns error" do
      started_at = DateTime.utc_now()

      assert {:error, :no_session_key} =
               ScrobbleActivity.scrobble_medium(1, @release, :started_at, started_at)
    end
  end

  describe "scrobble_tracks/4" do
    setup [:store_session_key, :stub_lastfm_success]

    setup do
      track_ids =
        @release
        |> Release.tracks()
        |> Enum.take(2)
        |> Enum.map(& &1.id)
        |> MapSet.new()

      %{track_ids: track_ids}
    end

    test "scrobbles selected tracks with :started_at", %{track_ids: track_ids} do
      started_at = DateTime.utc_now()

      assert {:ok, _} =
               ScrobbleActivity.scrobble_tracks(track_ids, @release, :started_at, started_at)
    end

    test "scrobbles selected tracks with :finished_at", %{track_ids: track_ids} do
      finished_at = DateTime.utc_now()

      assert {:ok, _} =
               ScrobbleActivity.scrobble_tracks(track_ids, @release, :finished_at, finished_at)
    end

    test "returns error when no tracks selected" do
      started_at = DateTime.utc_now()

      assert {:error, :no_duration} =
               ScrobbleActivity.scrobble_tracks(MapSet.new(), @release, :started_at, started_at)
    end

    test "returns error when selected tracks have zero length" do
      zero_track = %Track{
        id: "zero",
        title: "Silent",
        length: 0,
        artists: [],
        number: "1",
        position: 1
      }

      release = %{
        @release
        | media: [
            %Medium{title: "", format: "CD", number: 1, track_count: 1, tracks: [zero_track]}
          ]
      }

      started_at = DateTime.utc_now()

      assert {:error, :no_duration} =
               ScrobbleActivity.scrobble_tracks(
                 MapSet.new(["zero"]),
                 release,
                 :started_at,
                 started_at
               )
    end
  end

  describe "scrobble_tracks/4 without session key" do
    setup [:stub_lastfm_success]

    test "returns error" do
      track_ids =
        @release
        |> Release.tracks()
        |> Enum.take(1)
        |> Enum.map(& &1.id)
        |> MapSet.new()

      started_at = DateTime.utc_now()

      assert {:error, :no_session_key} =
               ScrobbleActivity.scrobble_tracks(track_ids, @release, :started_at, started_at)
    end
  end

  describe "scrobble construction" do
    setup [:store_session_key]

    test "populates correct fields and increments timestamps" do
      started_at = ~U[2024-01-01 12:00:00Z]

      Req.Test.stub(LastFm.API, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = URI.decode_query(body)

        # First track should have timestamp = started_at + track length
        first_track = Enum.at(Release.tracks(@release), 0)
        expected_timestamp = DateTime.add(started_at, first_track.length, :millisecond)

        assert params["track[0]"] == first_track.title
        assert params["artist[0]"] == first_track.artists |> List.first() |> Map.get(:name)
        assert params["album[0]"] == @release.title
        assert params["timestamp[0]"] == Integer.to_string(DateTime.to_unix(expected_timestamp))

        Req.Test.json(conn, %{"scrobbles" => %{"@attr" => %{"accepted" => 1}}})
      end)

      assert {:ok, _} = ScrobbleActivity.scrobble_release(@release, :started_at, started_at)
    end

    test "sets album_artist when track artist differs from release artist" do
      different_artist = %Artist{id: "a2", name: "Guest Artist", sort_name: "Guest"}

      track = %Track{
        id: "t1",
        title: "Collab",
        length: 60_000,
        artists: [different_artist],
        number: "1",
        position: 1
      }

      medium = %Medium{title: "", format: "CD", number: 1, track_count: 1, tracks: [track]}
      release = %{@release | media: [medium]}

      Req.Test.stub(LastFm.API, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = URI.decode_query(body)

        release_artist = @release.artists |> List.first() |> Map.get(:name)
        assert params["album_artist[0]"] == release_artist

        Req.Test.json(conn, %{"scrobbles" => %{"@attr" => %{"accepted" => 1}}})
      end)

      assert {:ok, _} =
               ScrobbleActivity.scrobble_release(release, :started_at, ~U[2024-01-01 12:00:00Z])
    end

    test "does not set album_artist when track artist matches release artist" do
      track_ids =
        @release
        |> Release.tracks()
        |> Enum.take(1)
        |> Enum.map(& &1.id)
        |> MapSet.new()

      Req.Test.stub(LastFm.API, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = URI.decode_query(body)

        refute Map.has_key?(params, "album_artist[0]")

        Req.Test.json(conn, %{"scrobbles" => %{"@attr" => %{"accepted" => 1}}})
      end)

      assert {:ok, _} =
               ScrobbleActivity.scrobble_tracks(
                 track_ids,
                 @release,
                 :started_at,
                 ~U[2024-01-01 12:00:00Z]
               )
    end
  end
end
