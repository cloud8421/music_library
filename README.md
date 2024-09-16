# MusicLibrary

To start your Phoenix server:

- Run `mix setup` to install and setup dependencies
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix

## Dev Notes

### Search

- SQLite supports full-text search via the built-in FTS5 extension, which is enabled by default and loaded in the Elixir Driver.
  The extension requires building a virtual table that holds the data to be searched. This seems to be akin to a materialized view.
- To have fuzzy search, another extension needs to be loaded.
  [Exqlite](https://github.com/elixir-sqlite/exqlite?tab=readme-ov-file) recommends using [ExSqlean](https://github.com/mindreframer/ex_sqlean),
  which in turn uses [Sqlean](https://github.com/mindreframer/sqlean), but the extension is NOT part of the ExSQlean set.
  Need to investigate with forking and PR.
