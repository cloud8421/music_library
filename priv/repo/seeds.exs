# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     MusicLibrary.Repo.insert!(%MusicLibrary.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

case System.argv() do
  [] ->
    IO.puts("Error: requires the path to the obsidian vault record folder")
    System.halt(1)

  [path] ->
    # TODO: validate path
    IO.puts("Seeding the database from #{path}")

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

    IO.puts("Parsed #{length(valid)} entries")
    IO.puts("Failed to parse #{length(errors)} entries")

    MusicLibrary.Repo.insert_all(MusicLibrary.Records.Record, valid)

  _other ->
    IO.puts("Error: too many arguments")
    System.halt(1)
end
