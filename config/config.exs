# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :elixir, :time_zone_database, TimeZoneInfo.TimeZoneDatabase

config :time_zone_info, update: :daily

config :music_library,
  ecto_repos: [MusicLibrary.BackgroundRepo, MusicLibrary.Repo, MusicLibrary.ErrorRepo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :music_library, MusicLibraryWeb,
  login_password: "change me",
  api_token: "change me",
  timezone: "Europe/London"

# Configures the endpoint
config :music_library, MusicLibraryWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MusicLibraryWeb.ErrorHTML, json: MusicLibraryWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MusicLibrary.PubSub,
  live_view: [signing_salt: "g/qw4SNo"]

user_agent = "MusicLibrary/0.1.0 ( cloud8421@gmail.com )"

config :music_library, LastFm,
  user: "username",
  auto_refresh: true,
  refresh_interval: System.convert_time_unit(60, :second, :millisecond),
  api_key: "change me",
  shared_secret: "change me",
  user_agent: user_agent

config :music_library, MusicBrainz, user_agent: user_agent

config :music_library, Discogs, personal_access_token: "change me", user_agent: user_agent

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.5",
  music_library: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.11",
  music_library: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use JSON for JSON parsing in Phoenix
config :phoenix, :json_library, JSON

config :error_tracker,
  repo: MusicLibrary.ErrorRepo,
  otp_app: :music_library,
  enabled: true

config :music_library, Oban,
  engine: Oban.Engines.Lite,
  queues: [default: 10, heavy_writes: 1, music_brainz: 1],
  repo: MusicLibrary.BackgroundRepo,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       # every hour
       {"0 * * * *", MusicLibrary.Worker.PolyfillScrobbledTracks},
       # every 30 minutes
       {"*/30 * * * *", MusicLibrary.ScrobbleRules.Worker}
     ]}
  ]

config :music_library, MusicLibrary.ErrorRepo, priv: "priv/error_repo"

config :music_library, MusicLibrary.BackgroundRepo, priv: "priv/background_repo"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
