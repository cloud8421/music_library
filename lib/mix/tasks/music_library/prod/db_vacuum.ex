defmodule Mix.Tasks.MusicLibrary.Prod.DbVacuum do
  use Mix.Task
  @shortdoc "Force VACUUM the production database"
  @moduledoc """
  Force VACUUM the production database. This is necessary to make sure that all
  changes currently in the WAL are persisted to the sqlite database file.

  Requires the `flyctl` CLI to be installed and authenticated.
  """

  import Mix.Tasks.MusicLibrary.Prod.Helpers

  @impl Mix.Task
  def run(_args) do
    Mix.Shell.IO.info("Running VACUUM on the production database")

    command = ~s(bin/music_library rpc 'MusicLibrary.Repo.vacuum\(\)')

    fly_ssh(command)
  end
end
