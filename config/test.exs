import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :music_library, MusicLibrary.Repo,
  database: Path.expand("../data/music_library_test.db", __DIR__),
  # Double the amount of concurrent tests
  pool_size: 32,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :music_library, MusicLibraryWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "by2RtUuJGgxQtt6p33/ump015WMPo5WQkh3MlFhUYwRrVxMOm4RT55pOt+tVKAES",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :music_library, dev_routes: true

config :music_library, LastFm, auto_refresh: false
