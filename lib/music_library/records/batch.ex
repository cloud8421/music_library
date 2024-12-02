defmodule MusicLibrary.Records.Batch do
  require Logger

  alias MusicLibrary.Records.{Cover, Record}
  alias MusicLibrary.Repo
  import Ecto.Query

  def refresh_musicbrainz_data do
    run_on_all_records(fn record ->
      import_musicbrainz_data(record)
      Process.sleep(1000)
    end)
  end

  def import_musicbrainz_data(record) do
    with {:ok, data} <- musicbrainz().get_release_group(record.musicbrainz_id) do
      record
      |> Record.add_musicbrainz_data(data)
      |> Repo.update!()
    end
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

  def update_release_ids do
    run_on_all_records(&update_release_ids/1)
  end

  def update_included_release_group_ids do
    run_on_all_records(&update_included_release_group_ids/1)
  end

  def update_release_ids(record) do
    record
    |> Record.update_release_ids()
    |> Repo.update()
  end

  def update_included_release_group_ids(record) do
    record
    |> Record.update_included_release_group_ids()
    |> Repo.update()
  end

  def remove_artists_ids! do
    # Shotgun approach: remove the first 4 artists IDs from each record.
    # This is not a general solution, but it works as a quick fix because the record with the most artists has 3.
    q = "update records set artists = json_remove(artists, '$[0].id', '$[1].id', '$[2].id', '$[3].id');"
    Repo.query(q)
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

  defp musicbrainz do
    Application.get_env(:music_library, :musicbrainz, MusicBrainz.APIImpl)
  end
end
