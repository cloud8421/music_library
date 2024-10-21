# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :music_library,
  ecto_repos: [MusicLibrary.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :music_library, MusicLibraryWeb, auth_password: "change me"

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

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  music_library: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  music_library: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
