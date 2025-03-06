defmodule Mix.Tasks.Tailwind.UpdateVersion do
  use Mix.Task

  @shortdoc "Update the configured tailwind versino to latest."
  @moduledoc """
  Update the configured tailwind versino to latest.
  """

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started(:req)

    current_version =
      Application.get_env(:tailwind, :version)

    latest_version_url =
      "https://api.github.com/repos/tailwindlabs/tailwindcss/releases/latest"

    latest_version =
      Req.get!(latest_version_url).body["tag_name"]
      |> String.replace_prefix("v", "")

    if current_version !== latest_version do
      Mix.Shell.IO.info(
        "Updating tailwind configuration from #{current_version} to #{latest_version}"
      )

      config_file =
        Path.expand("config/config.exs", File.cwd!())

      config_contents = File.read!(config_file)

      new_config_contents =
        String.replace(
          config_contents,
          ~r{version: "#{current_version}"},
          "version: \"#{latest_version}\""
        )

      File.write!(config_file, new_config_contents)
    else
      Mix.Shell.IO.info("tailwind configuration is up to date (#{current_version})")
    end
  end
end
