defmodule LastFm.Worker.BackfillScrobbledTracks do
  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  alias MusicLibrary.BackgroundRepo

  @backfill_delay 5
  @batch_size 100

  @impl Oban.Worker
  def perform(%{args: %{"to_uts" => to_uts}}) do
    # importing is an all or nothing operation, which means that we can
    # use the returning count to determine if we reached the end of the backfilling
    # process.
    case LastFm.Import.batch(to_uts: to_uts, limit: @batch_size) do
      {@batch_size, nil} ->
        next_to_uts = LastFm.lowest_scrobbled_at_uts()

        %{"to_uts" => next_to_uts}
        |> new(schedule_in: @backfill_delay)
        |> BackgroundRepo.insert()

      {other_count, nil} when is_integer(other_count) ->
        :ok

      error ->
        error
    end
  end
end
