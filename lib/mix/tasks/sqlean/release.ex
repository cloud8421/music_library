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
    version_file()
    |> File.read!()
    |> String.trim()
  end

  def version_file do
    Application.app_dir(:music_library, [
      "priv",
      "sqlite_extensions",
      "VERSION"
    ])
  end

  def update_version_file!(version) do
    version_file()
    |> File.write!(version)
  end
end
