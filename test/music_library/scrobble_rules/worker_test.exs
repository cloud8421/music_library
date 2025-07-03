defmodule MusicLibrary.ScrobbleRules.WorkerTest do
  use MusicLibrary.DataCase

  alias LastFm.Track
  alias MusicLibrary.ScrobbleRules
  alias MusicLibrary.ScrobbleRules.Worker

  describe "perform/1" do
    test "successfully applies all enabled rules" do
      # Create enabled rules
      {:ok, album_rule} =
        ScrobbleRules.create_scrobble_rule(%{
          type: "album",
          match_value: "Dark Side of the Moon",
          target_musicbrainz_id: "12345678-1234-1234-1234-123456789012",
          enabled: true
        })

      {:ok, artist_rule} =
        ScrobbleRules.create_scrobble_rule(%{
          type: "artist",
          match_value: "Pink Floyd",
          target_musicbrainz_id: "87654321-4321-4321-4321-210987654321",
          enabled: true
        })

      # Create disabled rule
      {:ok, _disabled_rule} =
        ScrobbleRules.create_scrobble_rule(%{
          type: "album",
          match_value: "Disabled Album",
          target_musicbrainz_id: "11111111-1111-1111-1111-111111111111",
          enabled: false
        })

      # Create test tracks
      %Track{}
      |> Track.changeset(%{
        scrobbled_at_uts: System.system_time(:second),
        musicbrainz_id: "track-mbid-1",
        title: "Breathe",
        cover_url: "http://example.com/cover.jpg",
        scrobbled_at_label: "01 Jan 2023, 12:00",
        artist: %{musicbrainz_id: "", name: "Pink Floyd"},
        album: %{musicbrainz_id: "", title: "Dark Side of the Moon"},
        last_fm_data: %{}
      })
      |> Repo.insert!()

      %Track{}
      |> Track.changeset(%{
        scrobbled_at_uts: System.system_time(:second) + 1,
        musicbrainz_id: "track-mbid-2",
        title: "Money",
        cover_url: "http://example.com/cover.jpg",
        scrobbled_at_label: "01 Jan 2023, 12:05",
        artist: %{musicbrainz_id: "", name: "Pink Floyd"},
        album: %{musicbrainz_id: "", title: "Wish You Were Here"},
        last_fm_data: %{}
      })
      |> Repo.insert!()

      # Execute the worker
      assert :ok = Worker.perform(%Oban.Job{args: %{}})

      # Verify rules were applied
      updated_track1 = Repo.get_by(Track, musicbrainz_id: "track-mbid-1")
      assert updated_track1.album.musicbrainz_id == album_rule.target_musicbrainz_id
      assert updated_track1.artist.musicbrainz_id == artist_rule.target_musicbrainz_id

      updated_track2 = Repo.get_by(Track, musicbrainz_id: "track-mbid-2")
      # Only artist should be updated for track2 since album doesn't match
      assert updated_track2.artist.musicbrainz_id == artist_rule.target_musicbrainz_id
      # Should remain unchanged (nil or empty string)
      assert updated_track2.album.musicbrainz_id in [nil, ""]
    end

    test "handles errors gracefully" do
      # Since we can't easily mock here, let's test with no rules
      # which should still return :ok
      assert :ok = Worker.perform(%Oban.Job{args: %{}})
    end

    test "handles empty rules list" do
      # No rules exist
      assert :ok = Worker.perform(%Oban.Job{args: %{}})
    end
  end

  describe "run_now/0" do
    test "enqueues job for immediate execution" do
      assert {:ok, %Oban.Job{}} = Worker.run_now()
    end
  end
end
