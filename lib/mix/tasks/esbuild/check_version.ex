defmodule Mix.Tasks.Esbuild.CheckVersion do
  @shortdoc "Checks the the current Esbuild version is the latest"
  @moduledoc """
  Checks the the current esbuild version is the latest.

  Exits with 0 if versions match, 1 if the esbuild needs to be updated.
  """

  use Mix.Task

  alias Mix.Tasks.Esbuild.Release

  @impl Mix.Task
  def run(_args) do
    current_version = Release.fetch_current_version()
    latest_version = Release.fetch_latest_version!()

    if current_version !== latest_version do
      Mix.Shell.IO.info(
        "A new esbuild version is available: #{current_version} ==> #{latest_version}"
      )

      System.halt(1)
    else
      Mix.Shell.IO.info("The esbuild version is up to date (#{current_version})")
    end
  end
end
