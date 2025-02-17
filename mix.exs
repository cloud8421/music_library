defmodule MusicLibrary.MixProject do
  use Mix.Project

  def project do
    [
      app: :music_library,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {MusicLibrary.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Low-level tooling
      {:jason, "~> 1.2"},
      {:circular_buffer, "~> 0.4.1"},

      # Translations
      {:gettext, "~> 0.20"},

      # Web Server
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:phoenix, "~> 1.7.14"},

      # Database
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:ecto_sqlite3, ">= 0.0.0"},
      {:ecto_sqlite3_extras, "~> 1.2.2"},

      # UI
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_view, "~> 1.0.0"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},

      # Dev tooling
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},

      # HTTP Clients
      {:finch, "~> 0.19.0"},
      {:req, "~> 0.5.8"},

      # Parsing
      {:yaml_elixir, "~> 2.11"},
      {:nimble_parsec, "~> 1.4"},

      # Image manipulation
      {:vix, "~> 0.33.0"},

      # Data validation
      {:nimble_options, "~> 1.1"},

      # Test tooling
      {:phoenix_test, "~> 0.5.1", only: :test},
      {:floki, ">= 0.30.0", only: :test},
      {:mox, "~> 1.2", only: :test},

      # Prod error/perf tooling
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:error_tracker, "~> 0.5.1"},
      {:recon, "~> 2.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      # When running the migrate task WITHOUT setting the log_level option,
      # Ecto defaults to debug IRRESPECTIVELY of the log level set in
      # config/test.exs. The debug log level persists while the first 2-3
      # database connections are being opened before being reset to warning,
      # causing a few spurious log statements to appear. By forcing the log
      # level to warning at the task level, we avoid this issue.
      test: ["ecto.create --quiet", "ecto.migrate --quiet --log-level=warning", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind music_library", "esbuild music_library"],
      "assets.deploy": [
        "tailwind music_library --minify",
        "esbuild music_library --minify",
        "phx.digest"
      ],
      "music_library.prod.db_backup": [
        "music_library.prod.db_vacuum",
        "music_library.prod.db_pull"
      ]
    ]
  end
end
