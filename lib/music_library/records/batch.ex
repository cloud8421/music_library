defmodule MusicLibrary.Records.Batch do
  import Ecto.Query

  alias MusicLibrary.Records
  alias MusicLibrary.Records.{Cover, Record}
  alias MusicLibrary.Repo

  require Logger

  def refresh_musicbrainz_data(opts \\ []) do
    run_on_all_records(fn record ->
      sleep = Keyword.get(opts, :sleep, 2000)
      Records.refresh_musicbrainz_data(record)
      Process.sleep(sleep)
    end)
  end

  def refresh_musicbrainz_data_async do
    run_on_all_records(fn record ->
      Records.refresh_musicbrainz_data_async(record)
    end)
  end

  def refresh_old_artwork do
    run_on_all_records(&refresh_old_artwork/1)
  end

  def refresh_old_artwork(record) do
    if Cover.correct_size?(record.cover_data) do
      :ok
    else
      MusicLibrary.Records.refresh_cover(record)
    end
  end

  defp run_on_all_records(fun) do
    q = from(r in Record)
    stream = Repo.stream(q, max_rows: 50)

    Repo.transaction(
      fn ->
        Enum.reduce(stream, [], fn record, acc ->
          case fun.(record) do
            {:error, reason} ->
              Logger.error(
                "Failed to run function on record #{record.id} with #{inspect(reason)}"
              )

              [record.id | acc]

            :ok ->
              acc

            {:ok, _record} ->
              acc
          end
        end)
      end,
      timeout: :infinity
    )
  end
end
