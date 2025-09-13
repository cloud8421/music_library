defmodule Mix.Tasks.Sqlean.Release do
  @latest_version_info_url "https://raw.githubusercontent.com/nalgeon/sqlean/refs/heads/main/sqlpkg.json"

  def fetch_latest_version! do
    Application.ensure_all_started(:req)

    fetch_latest_version_info!()
    |> Map.get("version")
  end

  def fetch_current_version do
    version_file()
    |> File.read!()
    |> String.trim()
  end

  # https://github.com/nalgeon/sqlean/releases/download/0.28.0/sqlean-linux-arm64.zip
  def fetch_release_urls! do
    Application.ensure_all_started(:req)

    assets =
      fetch_latest_version_info!()
      |> get_in(["assets", "files"])

    version = fetch_latest_version!()

    Enum.map(assets, fn {arch, file} ->
      {arch, full_url(version, file)}
    end)
  end

  defp fetch_latest_version_info! do
    @latest_version_info_url
    |> Req.get!()
    |> Map.get(:body)
    |> JSON.decode!()
  end

  defp full_url(version, file) do
    "https://github.com/nalgeon/sqlean/releases/download/" <> version <> "/" <> file
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
