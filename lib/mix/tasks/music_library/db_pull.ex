defmodule Mix.Tasks.MusicLibrary.DbPull do
  use Mix.Task
  @shortdoc "Pulls the latest database from the production server"
  @moduledoc """
  Pulls the latest database from the production server.

  Requires the `flyctl` CLI to be installed and authenticated.
  """

  @impl Mix.Task
  def run(_args) do
    IO.puts("Pulling the latest database from the production server")

    current_time = DateTime.utc_now()
    remote_db = "/mnt/music_library/music_library_prod.db"
    local_db = "music_library_prod_#{DateTime.to_unix(current_time)}.db"

    System.cmd("flyctl", ["ssh", "sftp", "get", remote_db, local_db], into: IO.stream())
  end
end
