ExUnit.start(exclude: [:skip_in_memory_db])
Ecto.Adapters.SQL.Sandbox.mode(MusicLibrary.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(MusicLibrary.BackgroundRepo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(MusicLibrary.TelemetryRepo, :auto)
