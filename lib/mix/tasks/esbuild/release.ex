defmodule Mix.Tasks.Esbuild.Release do
  @latest_version_url "https://api.github.com/repos/evanw/esbuild/releases/latest"

  def fetch_latest_version! do
    Application.ensure_all_started(:req)

    Req.get!(@latest_version_url).body["tag_name"]
    |> String.replace_prefix("v", "")
  end

  def fetch_current_version do
    Application.get_env(:esbuild, :version)
  end

  def update_config_file!(config_file, current_version, latest_version) do
    config_contents = File.read!(config_file)

    new_config_contents =
      String.replace(
        config_contents,
        ~s(version: "#{current_version}"),
        "version: \"#{latest_version}\""
      )

    File.write!(config_file, new_config_contents)
  end
end
