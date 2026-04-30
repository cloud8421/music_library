defmodule MusicLibrary.Repo do
  @moduledoc """
  Main application repository using SQLite3 with FTS5 unicode and vec0 extensions.
  """

  use Ecto.Repo,
    otp_app: :music_library,
    adapter: Ecto.Adapters.SQLite3

  @doc """
  Returns `:ok` if the current OS/architecture has precompiled SQLite extensions
  available (unicode, vec0). Raises `RuntimeError` with a diagnostic message
  including the detected platform and supported alternatives.
  """
  def ensure_supported_platform! do
    case platform_string() do
      {:ok, _platform} -> :ok
      {:error, os, arch} -> raise_unsupported_platform(os, arch)
    end
  end

  @doc """
  Returns `true` if the current OS/architecture has precompiled SQLite extensions
  available (unicode, vec0).
  """
  def supported_platform? do
    match?({:ok, _}, platform_string())
  end

  @doc """
  Returns the filesystem path for a named SQLite extension.

  Only macOS (Intel/Apple Silicon) and Linux (amd64/arm64) are supported.
  """
  def extension_path(name) do
    platform = platform_string!()
    {_, os} = :os.type()

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

  defp raise_unsupported_platform(os, arch) do
    raise """
    Unsupported platform: #{os} / #{arch}

    This application ships precompiled SQLite extensions (unicode, vec0) for:
      • darwin-amd64  (macOS Intel)
      • darwin-arm64  (macOS Apple Silicon)
      • linux-amd64   (Linux x86_64)
      • linux-arm64   (Linux aarch64)

    Your platform (#{inspect(os)} / #{arch}) is not supported. The SQLite extensions
    required for full-text search (unicode) and vector similarity search (vec0)
    cannot be loaded on this architecture.

    To run on this platform, provide compatible builds of these extensions in
    priv/sqlite_extensions/#{os}-#{arch}/.
    """
  end

  defp platform_string! do
    case platform_string() do
      {:ok, platform} -> platform
      {:error, _os, _arch} -> raise "Unsupported OS or platform"
    end
  end

  defp platform_string do
    [arch | _rest] =
      :erlang.system_info(:system_architecture)
      |> List.to_string()
      |> String.split("-")

    {_, os} = :os.type()

    case {os, arch} do
      {:darwin, "x86_64"} -> {:ok, "darwin-amd64"}
      {:darwin, "aarch64"} -> {:ok, "darwin-arm64"}
      {:linux, "x86_64"} -> {:ok, "linux-amd64"}
      {:linux, "aarch64"} -> {:ok, "linux-arm64"}
      _ -> {:error, os, arch}
    end
  end

  def vacuum, do: query("VACUUM")

  def optimize, do: query("PRAGMA optimize")
end
