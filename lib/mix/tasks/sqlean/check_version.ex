defmodule Mix.Tasks.Sqlean.CheckVersion do
  @shortdoc "Checks the the current Sqlean extensions version is the latest"
  @moduledoc """
  Checks the the current Sqlean extensions version is the latest.

  Exits with 0 if versions match, 1 if the extensions needs to be updated.
  """

  use Mix.Task

  alias Mix.Tasks.Sqlean.Release

  @impl Mix.Task
  def run(_args) do
    current_version =
      Release.fetch_current_version()

    latest_version =
      Release.fetch_latest_version!()

    if current_version === latest_version do
      Mix.Shell.IO.info("The sqlean extensions version is up to date (#{current_version})")
    else
      Mix.Shell.IO.info(
        "A new sqlean extensions version is available: #{current_version} ==> #{latest_version}"
      )

      System.halt(1)
    end
  end
end
