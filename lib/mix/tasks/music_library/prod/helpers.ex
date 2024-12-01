defmodule Mix.Tasks.MusicLibrary.Prod.Helpers do
  def fly_ssh(command) do
    if flyctl_installed?() do
      System.cmd("flyctl", ["ssh", "console", "--command", command], into: IO.stream())
    else
      IO.puts("Please install flyctl first")
      System.halt(1)
    end
  end

  def fly_sftp_get(remote_path, local_path) do
    if flyctl_installed?() do
      System.cmd("flyctl", ["ssh", "sftp", "get", remote_path, local_path], into: IO.stream())
    else
      IO.puts("Please install flyctl first")
      System.halt(1)
    end
  end

  defp flyctl_installed?() do
    System.find_executable("flyctl")
  end
end
