defmodule MusicLibrary.MaintenanceTest do
  use MusicLibrary.DataCase

  import MusicLibrary.ScrobbledTracksFixtures

  alias MusicLibrary.BackgroundRepo
  alias MusicLibrary.Maintenance

  describe "optimize/0" do
    test "runs PRAGMA optimize on the database" do
      assert {:ok, %Exqlite.Result{command: :execute}} = Maintenance.optimize()
    end
  end

  describe "count_active_jobs_by_worker/0" do
    @worker_a "Test.Worker.Alpha"
    @worker_b "Test.Worker.Beta"

    test "returns an empty map when there are no jobs" do
      assert Maintenance.count_active_jobs_by_worker() == %{}
    end

    test "returns counts grouped by worker for active jobs" do
      %{id: "1"}
      |> Oban.Job.new(worker: @worker_a)
      |> Oban.insert!()

      %{id: "2"}
      |> Oban.Job.new(worker: @worker_a)
      |> Oban.insert!()

      %{id: "3"}
      |> Oban.Job.new(worker: @worker_b)
      |> Oban.insert!()

      counts = Maintenance.count_active_jobs_by_worker()

      assert counts[@worker_a] == 2
      assert counts[@worker_b] == 1
    end

    test "only counts jobs in active states" do
      %{id: "1"}
      |> Oban.Job.new(worker: @worker_a)
      |> Oban.insert!()
      |> then(fn job ->
        BackgroundRepo.update_all(
          from(j in Oban.Job, where: j.id == ^job.id),
          set: [state: "completed"]
        )
      end)

      counts = Maintenance.count_active_jobs_by_worker()

      assert Map.get(counts, @worker_a, 0) == 0
    end
  end

  describe "count_tracks_missing_artist_musicbrainz_id/0" do
    test "returns zero when no tracks exist" do
      count = Maintenance.count_tracks_missing_artist_musicbrainz_id()

      assert count == 0
    end

    test "returns count of tracks with empty artist musicbrainz_id" do
      track_fixture(%{artist_musicbrainz_id: ""})
      track_fixture(%{artist_musicbrainz_id: ""})
      track_fixture(%{artist_musicbrainz_id: "valid-id"})

      count = Maintenance.count_tracks_missing_artist_musicbrainz_id()

      assert count == 2
    end
  end

  describe "count_tracks_missing_album_musicbrainz_id/0" do
    test "returns zero when no tracks exist" do
      count = Maintenance.count_tracks_missing_album_musicbrainz_id()

      assert count == 0
    end

    test "returns count of tracks with empty album musicbrainz_id" do
      track_fixture(%{album_musicbrainz_id: ""})
      track_fixture(%{album_musicbrainz_id: ""})
      track_fixture(%{album_musicbrainz_id: "valid-id"})

      count = Maintenance.count_tracks_missing_album_musicbrainz_id()

      assert count == 2
    end
  end

  describe "get_artists_missing_musicbrainz_id/1" do
    test "returns empty list when no tracks exist" do
      result = Maintenance.get_artists_missing_musicbrainz_id()

      assert result == []
    end

    test "returns artists grouped by name with track counts" do
      track_fixture(%{artist_name: "Artist A", artist_musicbrainz_id: ""})
      track_fixture(%{artist_name: "Artist A", artist_musicbrainz_id: ""})
      track_fixture(%{artist_name: "Artist B", artist_musicbrainz_id: ""})

      result = Maintenance.get_artists_missing_musicbrainz_id()

      assert Enum.count_until(result, 3) == 2

      artist_a = Enum.find(result, fn r -> r.artist_name == "Artist A" end)
      artist_b = Enum.find(result, fn r -> r.artist_name == "Artist B" end)

      assert artist_a.track_count == 2
      assert artist_b.track_count == 1
    end

    test "orders artists by track count descending" do
      track_fixture(%{artist_name: "Artist A", artist_musicbrainz_id: ""})
      track_fixture(%{artist_name: "Artist B", artist_musicbrainz_id: ""})
      track_fixture(%{artist_name: "Artist B", artist_musicbrainz_id: ""})
      track_fixture(%{artist_name: "Artist B", artist_musicbrainz_id: ""})

      result = Maintenance.get_artists_missing_musicbrainz_id()

      assert Enum.count_until(result, 3) == 2
      assert List.first(result).artist_name == "Artist B"
      assert List.first(result).track_count == 3
    end

    test "limits results when limit option provided" do
      track_fixture(%{artist_name: "Artist A", artist_musicbrainz_id: ""})
      track_fixture(%{artist_name: "Artist B", artist_musicbrainz_id: ""})
      track_fixture(%{artist_name: "Artist C", artist_musicbrainz_id: ""})

      result = Maintenance.get_artists_missing_musicbrainz_id(limit: 2)

      assert Enum.count_until(result, 3) == 2
    end

    test "excludes artists with valid musicbrainz_id" do
      track_fixture(%{artist_name: "Artist A", artist_musicbrainz_id: ""})
      track_fixture(%{artist_name: "Artist B", artist_musicbrainz_id: "valid-id"})

      result = Maintenance.get_artists_missing_musicbrainz_id()

      assert Enum.count_until(result, 2) == 1
      assert List.first(result).artist_name == "Artist A"
    end
  end

  describe "get_albums_missing_musicbrainz_id/1" do
    test "returns empty list when no tracks exist" do
      result = Maintenance.get_albums_missing_musicbrainz_id()

      assert result == []
    end

    test "returns albums grouped by title and artist with track counts" do
      track_fixture(%{
        album_title: "Album A",
        artist_name: "Artist X",
        album_musicbrainz_id: ""
      })

      track_fixture(%{
        album_title: "Album A",
        artist_name: "Artist X",
        album_musicbrainz_id: ""
      })

      track_fixture(%{
        album_title: "Album B",
        artist_name: "Artist Y",
        album_musicbrainz_id: ""
      })

      result = Maintenance.get_albums_missing_musicbrainz_id()

      assert Enum.count_until(result, 3) == 2

      album_a = Enum.find(result, fn r -> r.album_title == "Album A" end)
      album_b = Enum.find(result, fn r -> r.album_title == "Album B" end)

      assert album_a.track_count == 2
      assert album_a.artist_name == "Artist X"
      assert album_b.track_count == 1
      assert album_b.artist_name == "Artist Y"
    end

    test "orders albums by track count descending" do
      track_fixture(%{album_title: "Album A", album_musicbrainz_id: ""})
      track_fixture(%{album_title: "Album B", album_musicbrainz_id: ""})
      track_fixture(%{album_title: "Album B", album_musicbrainz_id: ""})
      track_fixture(%{album_title: "Album B", album_musicbrainz_id: ""})

      result = Maintenance.get_albums_missing_musicbrainz_id()

      assert Enum.count_until(result, 3) == 2
      assert List.first(result).album_title == "Album B"
      assert List.first(result).track_count == 3
    end

    test "limits results when limit option provided" do
      track_fixture(%{album_title: "Album A", album_musicbrainz_id: ""})
      track_fixture(%{album_title: "Album B", album_musicbrainz_id: ""})
      track_fixture(%{album_title: "Album C", album_musicbrainz_id: ""})

      result = Maintenance.get_albums_missing_musicbrainz_id(limit: 2)

      assert Enum.count_until(result, 3) == 2
    end

    test "excludes albums with valid musicbrainz_id" do
      track_fixture(%{album_title: "Album A", album_musicbrainz_id: ""})
      track_fixture(%{album_title: "Album B", album_musicbrainz_id: "valid-id"})

      result = Maintenance.get_albums_missing_musicbrainz_id()

      assert Enum.count_until(result, 2) == 1
      assert List.first(result).album_title == "Album A"
    end
  end
end
