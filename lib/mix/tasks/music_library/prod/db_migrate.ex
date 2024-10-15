defmodule Mix.Tasks.MusicLibrary.Prod.DbMigrate do
  use Mix.Task
  @shortdoc "Run migrations on the production database"
  @moduledoc """
  Run migrations on the production database.

  Requires the `flyctl` CLI to be installed and authenticated.
  """

  @impl Mix.Task
  def run(_args) do
    IO.puts("Running migrations on production database")

    System.cmd("flyctl", ["ssh", "console", "--command", "bin/migrate"], into: IO.stream())
  end
end
