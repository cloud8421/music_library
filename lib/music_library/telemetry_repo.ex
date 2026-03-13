defmodule MusicLibrary.TelemetryRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :music_library,
    adapter: Ecto.Adapters.SQLite3
end
