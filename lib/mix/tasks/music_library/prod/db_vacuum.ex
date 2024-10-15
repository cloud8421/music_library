defmodule Mix.Tasks.MusicLibrary.Prod.DbVacuum do
  use Mix.Task
  @shortdoc "Force VACUUM the production database"
  @moduledoc """
  Force VACUUM the production database. This is necessary to make sure that all
  changes currently in the WAL are persisted to the sqlite database file.

  Requires the `flyctl` CLI to be installed and authenticated.
  """

  @impl Mix.Task
  def run(_args) do
    IO.puts("Running VACUUM on the production database")

    command = ~s(bin/music_library rpc 'MusicLibrary.Repo.query\("VACUUM"\)')

    System.cmd("flyctl", ["ssh", "console", "--command", command], into: IO.stream())
  end
end
