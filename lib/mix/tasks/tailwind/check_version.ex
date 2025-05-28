defmodule Mix.Tasks.Tailwind.CheckVersion do
  @shortdoc "Checks the the current Tailwind version is the latest"
  @moduledoc """
  Checks the the current Tailwind version is the latest.

  Exits with 0 if versions match, 1 if the Tailwind needs to be updated.
  """

  use Mix.Task

  alias Mix.Tasks.Tailwind.Release

  @impl Mix.Task
  def run(_args) do
    current_version = Release.fetch_current_version()
    latest_version = Release.fetch_latest_version!()

    if current_version !== latest_version do
      Mix.Shell.IO.info(
        "A new tailwind version is available: #{current_version} ==> #{latest_version}"
      )

      System.halt(1)
    else
      Mix.Shell.IO.info("The tailwind version is up to date (#{current_version})")
    end
  end
end
