defmodule Mix.Tasks.Scrobble.AuditTest do
  use MusicLibrary.DataCase

  import ExUnit.CaptureIO
  import MusicLibrary.ScrobbledTracksFixtures

  alias Mix.Tasks.Scrobble.Audit

  describe "run/1" do
    test "generates audit report with no tracks" do
      output =
        capture_io(fn ->
          Audit.run([])
        end)

      assert output =~ "Scrobbled Tracks Data Quality Audit"
      assert output =~ "Total scrobbled tracks: 0"
    end

    test "generates audit report with tracks having missing artist musicbrainz_ids" do
      # Create tracks with empty artist musicbrainz_id
      track_fixture(%{
        artist_name: "Test Artist 1",
        artist_musicbrainz_id: "",
        title: "Track 1"
      })

      track_fixture(%{
        artist_name: "Test Artist 1",
        artist_musicbrainz_id: "",
        title: "Track 2"
      })

      track_fixture(%{
        artist_name: "Test Artist 2",
        artist_musicbrainz_id: "",
        title: "Track 3"
      })

      output =
        capture_io(fn ->
          Audit.run([])
        end)

      assert output =~ "Artists with Missing MusicBrainz IDs"
      assert output =~ "Unique artists: 2"
      assert output =~ "Affected tracks: 3"
      assert output =~ "Test Artist 1"
      assert output =~ "Test Artist 2"
    end

    test "generates audit report with tracks having missing album musicbrainz_ids" do
      # Create tracks with empty album musicbrainz_id
      track_fixture(%{
        album_title: "Test Album 1",
        album_musicbrainz_id: "",
        artist_name: "Test Artist",
        title: "Track 1"
      })

      track_fixture(%{
        album_title: "Test Album 1",
        album_musicbrainz_id: "",
        artist_name: "Test Artist",
        title: "Track 2"
      })

      output =
        capture_io(fn ->
          Audit.run([])
        end)

      assert output =~ "Albums with Missing MusicBrainz IDs"
      assert output =~ "Unique albums: 1"
      assert output =~ "Affected tracks: 2"
      assert output =~ "Test Album 1"
    end

    test "generates audit report with --verbose flag" do
      track_fixture(%{
        artist_name: "Test Artist",
        artist_musicbrainz_id: "",
        title: "Test Track",
        album_title: "Test Album"
      })

      output =
        capture_io(fn ->
          Audit.run(["--verbose"])
        end)

      assert output =~ "Sample tracks:"
      assert output =~ "Test Artist"
      assert output =~ "Test Track"
    end

    test "generates audit report for artists only with --type artist" do
      track_fixture(%{
        artist_name: "Test Artist",
        artist_musicbrainz_id: "",
        album_musicbrainz_id: "",
        title: "Track 1"
      })

      output =
        capture_io(fn ->
          Audit.run(["--type", "artist"])
        end)

      assert output =~ "Artists with Missing MusicBrainz IDs"
      refute output =~ "Albums with Missing MusicBrainz IDs"
    end

    test "generates audit report for albums only with --type album" do
      track_fixture(%{
        album_title: "Test Album",
        album_musicbrainz_id: "",
        artist_musicbrainz_id: "",
        title: "Track 1"
      })

      output =
        capture_io(fn ->
          Audit.run(["--type", "album"])
        end)

      assert output =~ "Albums with Missing MusicBrainz IDs"
      refute output =~ "Artists with Missing MusicBrainz IDs"
    end

    test "generates JSON output with --format json" do
      track_fixture(%{
        artist_name: "Test Artist",
        artist_musicbrainz_id: "",
        title: "Track 1"
      })

      output =
        capture_io(fn ->
          Audit.run(["--format", "json"])
        end)

      assert output =~ ~s("total_tracks")
      assert output =~ ~s("artist_issues")
      assert output =~ ~s("album_issues")

      # Validate it's valid JSON
      assert {:ok, _parsed} = Jason.decode(output)
    end

    test "audit report shows summary with remediation steps" do
      track_fixture(%{
        artist_name: "Test Artist",
        artist_musicbrainz_id: "",
        title: "Track 1"
      })

      output =
        capture_io(fn ->
          Audit.run([])
        end)

      assert output =~ "Summary"
      assert output =~ "To fix these issues:"
      assert output =~ "Create scrobble rules"
      assert output =~ "MusicLibrary.ScrobbleRules.apply_all_rules()"
    end
  end
end
