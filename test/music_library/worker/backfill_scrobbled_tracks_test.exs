defmodule MusicLibrary.Worker.BackfillScrobbledTracksTest do
  use MusicLibrary.DataCase

  import MusicLibrary.ScrobbledTracksFixtures

  alias MusicLibrary.{BackgroundRepo, ListeningStats}
  alias MusicLibrary.Worker.BackfillScrobbledTracks

  describe "unique constraint" do
    test "deduplicates enqueue for the same to_uts" do
      to_uts = 1_700_000_000

      assert {:ok, first} =
               BackfillScrobbledTracks.new(%{"to_uts" => to_uts})
               |> Oban.insert()

      assert {:ok, %Oban.Job{conflict?: true} = second} =
               BackfillScrobbledTracks.new(%{"to_uts" => to_uts})
               |> Oban.insert()

      assert second.id == first.id
    end

    test "allows a new enqueue after previous job completes" do
      to_uts = 1_700_000_001

      {:ok, job} =
        BackfillScrobbledTracks.new(%{"to_uts" => to_uts})
        |> Oban.insert()

      BackgroundRepo.update_all(
        from(j in Oban.Job, where: j.id == ^job.id),
        set: [state: "completed"]
      )

      assert {:ok, new_job} =
               BackfillScrobbledTracks.new(%{"to_uts" => to_uts})
               |> Oban.insert()

      refute new_job.conflict?
      assert new_job.id != job.id
    end

    test "deduplicates old incomplete jobs for the same to_uts" do
      to_uts = 1_700_000_002

      assert {:ok, first} =
               BackfillScrobbledTracks.new(%{"to_uts" => to_uts})
               |> Oban.insert()

      BackgroundRepo.update_all(
        from(j in Oban.Job, where: j.id == ^first.id),
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -7_200, :second)]
      )

      assert {:ok, %Oban.Job{conflict?: true} = second} =
               BackfillScrobbledTracks.new(%{"to_uts" => to_uts})
               |> Oban.insert()

      assert second.id == first.id
    end

    test "deduplicates through ListeningStats.backfill_scrobbled_tracks/0" do
      to_uts = 1_700_000_003
      track_fixture(%{scrobbled_at_uts: to_uts})

      assert {:ok, first} = ListeningStats.backfill_scrobbled_tracks()
      assert first.args == %{"to_uts" => to_uts}

      assert {:ok, %Oban.Job{conflict?: true} = second} =
               ListeningStats.backfill_scrobbled_tracks()

      assert second.id == first.id
    end
  end
end
