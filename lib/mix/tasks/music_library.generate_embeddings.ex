defmodule Mix.Tasks.MusicLibrary.GenerateEmbeddings do
  @moduledoc """
  Generates embeddings for records.

  ## Usage

      # Generate embeddings for all records without embeddings
      mix music_library.generate_embeddings

      # Regenerate embeddings for all records (force)
      mix music_library.generate_embeddings --force

      # Generate embeddings for specific record IDs
      mix music_library.generate_embeddings --ids=id1,id2,id3

  ## Options

    * `--force` - Regenerate embeddings for all records, even if they already exist
    * `--ids` - Comma-separated list of record IDs to process
  """
  use Mix.Task

  import Ecto.Query

  alias MusicLibrary.Repo
  alias MusicLibrary.Records.{Record, RecordEmbedding}
  alias MusicLibrary.Worker.GenerateRecordEmbedding

  @shortdoc "Generates embeddings for records"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _} =
      OptionParser.parse!(args,
        strict: [force: :boolean, ids: :string],
        aliases: [f: :force, i: :ids]
      )

    force? = Keyword.get(opts, :force, false)
    ids = parse_ids(Keyword.get(opts, :ids))

    records = get_records(force?, ids)
    total = length(records)

    Mix.shell().info("Found #{total} records to process...")

    records
    |> Enum.with_index(1)
    |> Enum.each(fn {record, index} ->
      Mix.shell().info("[#{index}/#{total}] Enqueueing job for: #{record.title}")

      %{record_id: record.id}
      |> GenerateRecordEmbedding.new()
      |> Oban.insert!()
    end)

    Mix.shell().info("\nSuccessfully enqueued #{total} embedding generation jobs.")
    Mix.shell().info("Monitor progress in Oban dashboard or logs.")
  end

  defp parse_ids(nil), do: []

  defp parse_ids(ids_string) do
    ids_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp get_records(force?, []) when force? do
    Record
    |> order_by(asc: :title)
    |> Repo.all()
  end

  defp get_records(false, []) do
    existing_record_ids =
      RecordEmbedding
      |> select([re], re.record_id)
      |> Repo.all()
      |> MapSet.new()

    Record
    |> order_by(asc: :title)
    |> Repo.all()
    |> Enum.reject(fn record -> MapSet.member?(existing_record_ids, record.id) end)
  end

  defp get_records(_force?, ids) when is_list(ids) and length(ids) > 0 do
    Record
    |> where([r], r.id in ^ids)
    |> Repo.all()
  end
end
