defmodule MusicLibrary.ListeningStatsTest do
  use MusicLibrary.DataCase

  import MusicLibrary.ArtistInfoFixtures
  import MusicLibrary.ScrobbledTracksFixtures

  alias MusicLibrary.ListeningStats

  describe "scrobble_count/0" do
    test "returns correct count" do
      initial_count = ListeningStats.scrobble_count()

      create_test_tracks(3)

      new_count = ListeningStats.scrobble_count()

      assert new_count == initial_count + 3
    end
  end

  describe "get_top_artists/1" do
    test "counts tracks with missing artist_infos records" do
      artist_info =
        artist_info_fixture(%{musicbrainz_data: %{"name" => "Thin Lizzy"}})

      artist_mbid = artist_info.id

      now = System.system_time(:second)

      # Two tracks with a matching artist_infos record
      track_fixture(%{
        artist_name: "Thin Lizzy",
        artist_musicbrainz_id: artist_mbid,
        title: "The Boys Are Back in Town",
        scrobbled_at_uts: now - 100
      })

      track_fixture(%{
        artist_name: "Thin Lizzy",
        artist_musicbrainz_id: artist_mbid,
        title: "Jailbreak",
        scrobbled_at_uts: now - 200
      })

      # One track with an empty musicbrainz_id (no matching artist_infos)
      track_fixture(%{
        artist_name: "Thin Lizzy",
        artist_musicbrainz_id: "",
        title: "Rosalie / Cowgirl's Song",
        scrobbled_at_uts: now - 300
      })

      results = ListeningStats.get_top_artists(limit: 10)

      # All 3 tracks should be counted as a single artist entry
      assert [thin_lizzy] = Enum.filter(results, fn r -> r.name == "Thin Lizzy" end)
      assert thin_lizzy.play_count == 3
      # MAX picks the real musicbrainz_id over the empty string
      assert thin_lizzy.musicbrainz_id == artist_mbid
    end

    test "returns image_hash from artist_infos when available" do
      artist_info =
        artist_info_fixture(%{
          musicbrainz_data: %{"name" => "Test Artist"},
          image_data_hash: "abc123"
        })

      artist_mbid = artist_info.id

      track_fixture(%{
        artist_name: "Test Artist",
        artist_musicbrainz_id: artist_mbid,
        title: "Track 1",
        scrobbled_at_uts: System.system_time(:second) - 100
      })

      [result] = ListeningStats.get_top_artists(limit: 10)

      assert result.image_hash == "abc123"
    end

    test "returns nil image_hash for tracks without artist_infos" do
      track_fixture(%{
        artist_name: "Unknown Artist",
        artist_musicbrainz_id: "",
        title: "Track 1",
        scrobbled_at_uts: System.system_time(:second) - 100
      })

      [result] = ListeningStats.get_top_artists(limit: 10)

      assert result.image_hash == nil
    end
  end

  describe "get_top_artists_by_days/2" do
    test "counts tracks with missing artist_infos records within date range" do
      artist_info =
        artist_info_fixture(%{musicbrainz_data: %{"name" => "Thin Lizzy"}})

      artist_mbid = artist_info.id

      now = DateTime.utc_now()
      now_unix = DateTime.to_unix(now)

      # Two tracks with matching artist_infos
      track_fixture(%{
        artist_name: "Thin Lizzy",
        artist_musicbrainz_id: artist_mbid,
        title: "The Boys Are Back in Town",
        scrobbled_at_uts: now_unix - 100
      })

      track_fixture(%{
        artist_name: "Thin Lizzy",
        artist_musicbrainz_id: artist_mbid,
        title: "Jailbreak",
        scrobbled_at_uts: now_unix - 200
      })

      # One track with empty musicbrainz_id
      track_fixture(%{
        artist_name: "Thin Lizzy",
        artist_musicbrainz_id: "",
        title: "Rosalie / Cowgirl's Song",
        scrobbled_at_uts: now_unix - 300
      })

      results =
        ListeningStats.get_top_artists_by_days(7,
          limit: 10,
          current_time: now,
          timezone: "Etc/UTC"
        )

      assert [thin_lizzy] = Enum.filter(results, fn r -> r.name == "Thin Lizzy" end)
      assert thin_lizzy.play_count == 3
    end
  end
end
