import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :music_library, MusicLibrary.Repo,
  database:
    Path.expand("../data/music_library_test#{System.get_env("MIX_TEST_PARTITION")}.db", __DIR__),
  # Double the amount of concurrent tests
  pool_size: 32,
  pool: Ecto.Adapters.SQL.Sandbox,
  busy_timeout: 20_000

config :music_library, MusicLibrary.BackgroundRepo,
  database:
    Path.expand(
      "../data/music_library_background_test#{System.get_env("MIX_TEST_PARTITION")}.db",
      __DIR__
    ),
  pool_size: 32,
  pool: Ecto.Adapters.SQL.Sandbox

config :music_library, MusicLibrary.TelemetryRepo,
  database:
    Path.expand(
      "../data/music_library_telemetry_test#{System.get_env("MIX_TEST_PARTITION")}.db",
      __DIR__
    ),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :music_library, MusicLibraryWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "by2RtUuJGgxQtt6p33/ump015WMPo5WQkh3MlFhUYwRrVxMOm4RT55pOt+tVKAES",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

config :phoenix,
  # Initialize plugs at runtime for faster test compilation
  plug_init_mode: :runtime,
  # Enable sorting query params in verified routes during tests
  sort_verified_routes_query_params: true

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :music_library, monitoring_routes: true

config :music_library, LastFm,
  auto_refresh: false,
  req_options: [
    plug: {Req.Test, LastFm.API},
    max_retries: 0
  ],
  api_cooldown: 0

config :music_library, MusicBrainz,
  req_options: [
    plug: {Req.Test, MusicBrainz.API},
    max_retries: 0
  ],
  api_cooldown: 0

config :music_library, Discogs,
  req_options: [
    plug: {Req.Test, Discogs.API},
    max_retries: 0
  ],
  api_cooldown: 0

config :music_library, Wikipedia,
  req_options: [
    plug: {Req.Test, Wikipedia.API},
    max_retries: 0
  ],
  api_cooldown: 0

config :music_library, BraveSearch,
  api_key: "test_key",
  req_options: [
    plug: {Req.Test, BraveSearch.API},
    max_retries: 0
  ],
  api_cooldown: 0

config :music_library, OpenAI,
  api_key: "test_key",
  req_options: [
    plug: {Req.Test, OpenAI.API},
    max_retries: 0
  ]

config :phoenix_test, :endpoint, MusicLibraryWeb.Endpoint

config :music_library, Oban, testing: :manual

config :music_library, MusicLibrary.Mailer, adapter: Swoosh.Adapters.Test
