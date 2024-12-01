defmodule Mix.Tasks.MusicLibrary.Prod.DbMigrate do
  use Mix.Task
  @shortdoc "Run migrations on the production database"
  @moduledoc """
  Run migrations on the production database.

  Requires the `flyctl` CLI to be installed and authenticated.
  """

  import Mix.Tasks.MusicLibrary.Prod.Helpers

  @impl Mix.Task
  def run(_args) do
    IO.puts("Running migrations on production database")

    fly_ssh("bin/migrate")
  end
end
