defmodule Mix.Tasks.MusicLibrary.Prod.DbPull do
  use Mix.Task
  @shortdoc "Pulls the latest database from the production server"
  @moduledoc """
  Pulls the latest database from the production server.

  Requires the `flyctl` CLI to be installed and authenticated.
  """
  import Mix.Tasks.MusicLibrary.Prod.Helpers

  @impl Mix.Task
  def run(_args) do
    IO.puts("Pulling the latest database from the production server")

    current_time = DateTime.utc_now()
    remote_db = "/mnt/music_library/music_library_prod.db"
    local_db = "data/music_library_prod_#{DateTime.to_unix(current_time)}.db"

    case fly_sftp_get(remote_db, local_db) do
      {_stream, 1} ->
        IO.puts("Failed to pull the database")
        System.halt(1)

      {_stream, 0} ->
        IO.puts("Database pulled successfully")

        IO.puts("Restoring as local dev database")

        Path.wildcard("data/music_library_dev.db*")
        |> Enum.each(&File.rm!/1)

        File.cp!(local_db, "data/music_library_dev.db")
    end
  end
end
