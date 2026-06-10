defmodule MusicLibrary.Worker.BulkCronWorkersTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.BackgroundRepo
  alias MusicLibrary.Worker.ArtistRefreshAllDiscogsData
  alias MusicLibrary.Worker.ArtistRefreshAllMusicBrainzData
  alias MusicLibrary.Worker.ArtistRefreshAllWikipediaData
  alias MusicLibrary.Worker.RecordGenerateAllEmbeddings
  alias MusicLibrary.Worker.RecordRefreshAllMusicBrainzData

  @bulk_workers [
    RecordRefreshAllMusicBrainzData,
    RecordGenerateAllEmbeddings,
    ArtistRefreshAllMusicBrainzData,
    ArtistRefreshAllDiscogsData,
    ArtistRefreshAllWikipediaData
  ]

  describe "unique constraint" do
    test "deduplicates immediate enqueues for all bulk workers" do
      Enum.each(@bulk_workers, &assert_unique_conflict/1)
    end

    test "allows a new enqueue after the previous bulk job completes" do
      Enum.each(@bulk_workers, &assert_completed_allows_new_enqueue/1)
    end

    test "deduplicates incomplete bulk jobs regardless of insertion age" do
      Enum.each(@bulk_workers, &assert_old_incomplete_conflict/1)
    end
  end

  describe "RecordRefreshAllMusicBrainzData" do
    test "enqueues per-record MusicBrainz refresh jobs" do
      rec = record()

      assert {:ok, []} = perform_job(RecordRefreshAllMusicBrainzData, %{})

      assert_enqueued worker: MusicLibrary.Worker.RecordRefreshMusicBrainzData,
                      args: %{id: rec.id}
    end
  end

  describe "RecordGenerateAllEmbeddings" do
    test "enqueues per-record embedding generation jobs" do
      rec = record()

      assert {:ok, []} = perform_job(RecordGenerateAllEmbeddings, %{})

      assert_enqueued worker: MusicLibrary.Worker.GenerateRecordEmbedding,
                      args: %{record_id: rec.id}
    end
  end

  describe "ArtistRefreshAllMusicBrainzData" do
    test "enqueues per-artist MusicBrainz refresh jobs" do
      rec = record()
      artist = hd(rec.artists)
      info = artist_info(artist.musicbrainz_id)

      assert {:ok, []} = perform_job(ArtistRefreshAllMusicBrainzData, %{})

      assert_enqueued worker: MusicLibrary.Worker.ArtistRefreshMusicBrainzData,
                      args: %{id: info.id}
    end
  end

  describe "ArtistRefreshAllDiscogsData" do
    test "enqueues per-artist Discogs refresh jobs" do
      rec = record()
      artist = hd(rec.artists)
      info = artist_info(artist.musicbrainz_id)

      assert {:ok, []} = perform_job(ArtistRefreshAllDiscogsData, %{})

      assert_enqueued worker: MusicLibrary.Worker.ArtistRefreshDiscogsData,
                      args: %{id: info.id}
    end
  end

  describe "ArtistRefreshAllWikipediaData" do
    test "enqueues per-artist Wikipedia refresh jobs" do
      rec = record()
      artist = hd(rec.artists)
      info = artist_info(artist.musicbrainz_id)

      assert {:ok, []} = perform_job(ArtistRefreshAllWikipediaData, %{})

      assert_enqueued worker: MusicLibrary.Worker.ArtistRefreshWikipediaData,
                      args: %{id: info.id}
    end
  end

  defp assert_unique_conflict(worker) do
    assert {:ok, first} = insert_worker(worker)
    assert_conflicting_insert(worker, first, "for an immediate duplicate")
  end

  defp assert_completed_allows_new_enqueue(worker) do
    assert {:ok, first} = insert_worker(worker)
    update_job(first, state: "completed")

    assert {:ok, second} = insert_worker(worker)
    refute second.conflict?, "#{inspect(worker)} should not conflict with completed jobs"
    assert second.id != first.id
  end

  defp assert_old_incomplete_conflict(worker) do
    assert {:ok, first} = insert_worker(worker)

    update_job(first,
      inserted_at:
        DateTime.utc_now()
        |> DateTime.add(-7_200, :second)
        |> DateTime.truncate(:second)
    )

    assert_conflicting_insert(worker, first, "for an old incomplete duplicate")
  end

  defp assert_conflicting_insert(worker, first, reason) do
    case insert_worker(worker) do
      {:ok, %Oban.Job{conflict?: true} = second} ->
        assert second.id == first.id,
               "#{inspect(worker)} should return the existing job #{reason}"

      other ->
        flunk("#{inspect(worker)} should conflict #{reason}, got: #{inspect(other)}")
    end
  end

  defp insert_worker(worker) do
    worker.new(%{})
    |> Oban.insert()
  end

  defp update_job(job, fields) do
    BackgroundRepo.update_all(
      from(j in Oban.Job, where: j.id == ^job.id),
      set: fields
    )
  end
end
