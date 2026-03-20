[
  import_deps: [:error_tracker, :ecto, :ecto_sql, :oban, :oban_web, :phoenix, :phoenix_live_view],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter, Quokka],
  attribute_formatters: %{class: CanonicalTailwind},
  canonical_tailwind: [pool_size: 2],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"],
  quokka: [
    only: [
      :blocks,
      :defs,
      :deprecations,
      :line_length,
      :module_directives,
      :pipes,
      :single_node,
      :tests
    ]
  ]
]
