defmodule MusicLibrary.Worker.BackfillScrobbledTracks do
  @moduledoc """
  Oban worker that backfills scrobbled tracks from Last.fm in batches.

  Self-chaining: after importing a full batch, enqueues itself with the
  next `to_uts` timestamp to continue backfilling.
  """

  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  alias MusicLibrary.{BackgroundRepo, ListeningStats}

  @backfill_delay 1
  @batch_size 200

  @impl Oban.Worker
  def perform(%{args: %{"to_uts" => to_uts}}) do
    case LastFm.Import.batch(to_uts: to_uts, limit: @batch_size) do
      {:ok, @batch_size} ->
        next_to_uts = ListeningStats.lowest_scrobbled_at_uts()

        %{"to_uts" => next_to_uts}
        |> new(schedule_in: @backfill_delay)
        |> BackgroundRepo.insert()

      {:ok, _other_count} ->
        :ok

      error ->
        error
    end
  end
end
