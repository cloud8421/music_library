defmodule Mix.Tasks.Tailwind.CheckVersion do
  use Mix.Task

  @shortdoc "Checks the the current Tailwind version is the latest"
  @moduledoc """
  Checks the the current Tailwind version is the latest.

  Exits with 0 if versions match, 1 if the Tailwind needs to be updated.
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
        "A new tailwind version is available: #{current_version} ==> #{latest_version}"
      )

      System.halt(1)
    else
      Mix.Shell.IO.info("The tailwind version is up to date (#{current_version})")
    end
  end
end
