[
  import_deps: [:ecto, :ecto_sql, :oban, :oban_web, :phoenix, :phoenix_live_view],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter, Quokka],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"],
  quokka: [
    only: [:module_directives, :pipes, :single_node]
  ]
]
