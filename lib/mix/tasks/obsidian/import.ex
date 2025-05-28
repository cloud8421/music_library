defmodule Mix.Tasks.Obsidian.Import do
  @shortdoc "Import records from an Obsidian Vault containing Media entries "
  @moduledoc """
  Import records from an Obsidian Vault containing Media entries.

  Requires the path of the vault as argument to the task:

  `mix obsidian.import path/to/vault`
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    case args do
      [] ->
        Mix.Shell.IO.error("Error: requires the path to the obsidian vault record folder")
        System.halt(1)

      [path] ->
        Mix.Shell.IO.info("Seeding the database from #{path}")

        %{valid: valid, errors: errors} =
          Path.wildcard("#{path}/*.md")
          |> Enum.reduce(%{valid: [], errors: []}, fn entry, acc ->
            file_stat = File.stat!(entry)

            case entry
                 |> File.read!()
                 |> Obsidian.Parser.from_file_contents() do
              {:ok, parsed_entry} ->
                inserted_at =
                  file_stat.ctime
                  |> NaiveDateTime.from_erl!()
                  |> DateTime.from_naive!("Etc/UTC")

                updated_at =
                  file_stat.mtime
                  |> NaiveDateTime.from_erl!()
                  |> DateTime.from_naive!("Etc/UTC")

                data =
                  parsed_entry
                  |> Map.put(:inserted_at, inserted_at)
                  |> Map.put(:updated_at, updated_at)

                %{acc | valid: [data | acc.valid]}

              {:error, error} ->
                %{acc | errors: [{entry, error} | acc.errors]}
            end
          end)

        Mix.Shell.IO.info("Parsed #{length(valid)} entries")
        Mix.Shell.IO.error("Failed to parse #{length(errors)} entries")

        MusicLibrary.Repo.insert_all(MusicLibrary.Records.Record, valid)

      _other ->
        Mix.Shell.IO.error("Error: too many arguments")
        System.halt(1)
    end
  end
end
