defmodule MusicLibrary.Repo do
  use Ecto.Repo,
    otp_app: :music_library,
    adapter: Ecto.Adapters.SQLite3

  def extension_path(name) do
    [arch | _rest] =
      :erlang.system_info(:system_architecture)
      |> List.to_string()
      |> String.split("-")

    {_, os} = :os.type()

    platform =
      case {os, arch} do
        {:darwin, "x86_64"} -> "darwin-amd64"
        {:darwin, "aarch64"} -> "darwin-arm64"
        {:linux, "x86_64"} -> "linux-amd64"
        {:linux, "aarch64"} -> "linux-arm64"
        _other -> raise "Unsupported OS or platform"
      end

    extension =
      case os do
        :darwin -> "dylib"
        :linux -> "so"
      end

    Application.app_dir(:music_library, [
      "priv",
      "sqlite_extensions",
      platform,
      "#{name}.#{extension}"
    ])
  end

  def vacuum, do: query("VACUUM")
end
