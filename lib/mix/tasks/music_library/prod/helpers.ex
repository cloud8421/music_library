defmodule Mix.Tasks.MusicLibrary.Prod.Helpers do
  def fly_ssh(command) do
    System.cmd("flyctl", ["ssh", "console", "--command", command], into: IO.stream())
  end

  def fly_sftp_get(remote_path, local_path) do
    System.cmd("flyctl", ["ssh", "sftp", "get", remote_path, local_path], into: IO.stream())
  end
end
