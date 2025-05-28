defmodule Mix.Tasks.Tailwind.UpdateVersion do
  @shortdoc "Update the configured tailwind versino to latest."
  @moduledoc """
  Update the configured tailwind versino to latest.
  """

  use Mix.Task

  alias Mix.Tasks.Tailwind.Release

  @impl Mix.Task
  def run(_args) do
    current_version = Release.fetch_current_version()
    latest_version = Release.fetch_latest_version!()

    if current_version !== latest_version do
      Mix.Shell.IO.info(
        "Updating tailwind configuration from #{current_version} to #{latest_version}"
      )

      config_file =
        Path.expand("config/config.exs", File.cwd!())

      Release.update_config_file!(config_file, current_version, latest_version)
    else
      Mix.Shell.IO.info("tailwind configuration is up to date (#{current_version})")
    end
  end
end
