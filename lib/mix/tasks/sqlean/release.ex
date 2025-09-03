defmodule Mix.Tasks.Sqlean.Release do
  @latest_version_url "https://raw.githubusercontent.com/nalgeon/sqlean/refs/heads/main/sqlpkg.json"

  def fetch_latest_version! do
    Application.ensure_all_started(:req)

    @latest_version_url
    |> Req.get!()
    |> Map.get(:body)
    |> JSON.decode!()
    |> Map.get("version")
  end

  def fetch_current_version do
    Application.app_dir(:music_library, [
      "priv",
      "sqlite_extensions",
      "VERSION"
    ])
    |> File.read!()
    |> String.trim()
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
