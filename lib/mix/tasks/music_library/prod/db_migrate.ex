defmodule Mix.Tasks.MusicLibrary.Prod.DbMigrate do
  @shortdoc "Run migrations on the production database"
  @moduledoc """
  Run migrations on the production database.

  Requires the `flyctl` CLI to be installed and authenticated.
  """

  use Mix.Task

  import Mix.Tasks.MusicLibrary.Prod.Helpers

  @impl Mix.Task
  def run(_args) do
    Mix.Shell.IO.info("==> Running migrations on production database")

    fly_ssh("bin/migrate")
  end
end
