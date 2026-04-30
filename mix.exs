defmodule MusicLibrary.MixProject do
  use Mix.Project

  def project do
    [
      app: :music_library,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      gettext: [write_reference_line_numbers: false],
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [
        ignore_modules: ignored_coverage_modules(),
        summary: [threshold: 75]
      ],
      usage_rules: usage_rules(),
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        flags: [:no_opaque]
      ]
    ]
  end

  # Modules excluded from coverage accounting:
  #
  # - Cron-only workers that run operations incompatible with the Ecto sandbox
  #   (VACUUM / OPTIMIZE outside a transaction) or whose behaviour beyond a
  #   delegate call is untestable.
  # - Ecto.Repo shells (boilerplate plus platform-exclusive `extension_path/1`
  #   branches that cannot all execute on a single host).
  # - Phoenix generator output (ErrorHTML, ErrorJSON, the MusicLibraryWeb `use`
  #   entrypoint) with no application behaviour.
  # - The SessionHTML module housing session templates.
  # - Telemetry instrumentation whose write paths are only reachable from real
  #   `:telemetry.execute/3` events emitted by external libraries.
  # - Vendored `SqliteVec.*` library code under `lib/sqlite_vec/`.
  # - Req Rate Limiter System Clock (exposes std library built-ins)
  # - All Mix tasks (developer tooling not exercised by the application test
  #   suite).
  defp ignored_coverage_modules do
    [
      MusicLibrary.Release,
      MusicLibrary.Repo,
      MusicLibrary.BackgroundRepo,
      MusicLibrary.Worker.RepoVacuum,
      MusicLibrary.Worker.RepoOptimize,
      MusicLibrary.Worker.SendRecordsOnThisDayEmail,
      MusicLibrary.Worker.RefreshScrobbles,
      MusicLibrary.Worker.BackfillScrobbledTracks,
      MusicLibraryWeb,
      MusicLibraryWeb.ErrorHTML,
      MusicLibraryWeb.ErrorJSON,
      MusicLibraryWeb.SessionHTML,
      MusicLibraryWeb.Telemetry,
      MusicLibraryWeb.Telemetry.Storage,
      Req.RateLimiter.SystemClock,
      ~r/^Mix\.Tasks\./,
      ~r/SqliteVec\./
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {MusicLibrary.Application, []},
      extra_applications: [:logger, :runtime_tools, :xmerl]
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

      # Translations
      {:gettext, "~> 1.0"},

      # Web Server
      {:bandit, "~> 1.5"},
      {:phoenix, "~> 1.8.0"},

      # Database
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:ecto_sqlite3, "~> 0.22.0"},
      {:cloak_ecto, "~> 1.3"},

      # UI
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_view, "~> 1.1"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:fluxon, "~> 2.3.0", repo: :fluxon},
      {:live_toast, "~> 0.8.0"},

      # Dev tooling
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:benchee, "~> 1.3", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.1", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: :dev, runtime: false},
      {:quokka, "~> 2.6", only: [:dev, :test], runtime: false},
      {:live_debugger, "~> 1.0", only: :dev},
      {:usage_rules, "~> 1.1", only: [:dev]},
      {:tidewave, "~> 0.5", only: :dev},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false, warn_if_outdated: true},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},

      # HTTP Clients
      {:finch, "~> 0.21.0"},
      {:req, "~> 0.5.8"},
      {:server_sent_events, "~> 1.0"},

      # Mailers
      {:idna, "~> 7.1", override: true},
      {:swoosh, "~> 1.22"},
      # not used direclty, but required by Swoosh
      {:multipart, "~> 0.6.0"},

      # Parsing
      {:nimble_parsec, "~> 1.4"},

      # Image manipulation
      {:vix, "~> 0.38.0"},
      {:dominant_colors, "~> 0.1.4"},
      {:briefly, "~> 0.5.0"},

      # Markdown rendering
      {:mdex, "~> 0.12.0"},

      # PDF generation
      {:typst, "~> 0.3.1"},

      # Syntax highlighting
      {:lumis, "~> 0.1"},

      # Time-zone support - requires mint and castore
      {:time_zone_info, "~> 0.7.8"},
      {:castore, "~> 1.0"},

      # Data validation
      {:nimble_options, "~> 1.1"},

      # Background Jobs
      {:oban, "~> 2.21"},
      {:oban_web, "~> 2.12"},

      # Test tooling
      {:phoenix_test, "~> 0.11.0", only: :test},
      {:lazy_html, ">= 0.1.0", only: :test},

      # Prod error/perf tooling
      {:error_tracker, "~> 0.7"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
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
      setup: [
        "deps.get",
        "ecto.setup",
        "assets.setup",
        "cmd npm ci --prefix assets",
        "assets.build",
        "usage_rules.sync"
      ],
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
      ]
    ]
  end

  defp usage_rules do
    [
      file: "AGENTS.md",
      usage_rules: [
        "usage_rules:all",
        :elixir,
        {:mdex, link: :at}
      ],
      skills: [
        location: ".claude/skills",
        build: [
          "ui-framework": [
            description:
              "Use this skill when working with LiveViews, UI components using the Phoenix framework, and in general ANY FILE THAT CONTAINS HTML. Use proactively when editing .heex files, LiveView modules, LiveComponents, or any component module under lib/music_library_web/components/.",
            usage_rules: [
              :phoenix,
              ~r/^phoenix_/,
              :fluxon
            ]
          ]
        ]
      ]
    ]
  end
end
