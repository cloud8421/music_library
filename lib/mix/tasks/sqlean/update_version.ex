defmodule Mix.Tasks.Sqlean.UpdateVersion do
  @shortdoc "Update the configured Sqlean versino to latest."
  @moduledoc """
  Update the configured sqlean versions to latest.
  """

  use Mix.Task

  alias Mix.Tasks.Sqlean.Release

  @impl Mix.Task
  def run(_args) do
    current_version = Release.fetch_current_version()
    latest_version = Release.fetch_latest_version!()

    if current_version === latest_version do
      Mix.Shell.IO.info("Sqlean extensions configuration is up to date (#{current_version})")
    else
      Mix.Shell.IO.info(
        "Updating Sqlean extensions configuration from #{current_version} to #{latest_version}"
      )

      Release.update_version_file!(latest_version)
    end
  end
end
