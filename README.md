# MusicLibrary

To start your Phoenix server:

- Run `mix setup` to install and setup dependencies
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

- Official website: <https://www.phoenixframework.org/>
- Guides: <https://hexdocs.pm/phoenix/overview.html>
- Docs: <https://hexdocs.pm/phoenix>
- Forum: <https://elixirforum.com/c/phoenix-forum>
- Source: <https://github.com/phoenixframework/phoenix>

## Dev Notes

### Search

- SQLite supports full-text search via the built-in FTS5 extension, which is enabled by default and loaded in the Elixir Driver.
  The extension requires building a virtual table that holds the data to be searched. This seems to be akin to a materialized view.
- To have fuzzy search, another extension needs to be loaded.
  [Exqlite](https://github.com/elixir-sqlite/exqlite?tab=readme-ov-file) recommends using [ExSqlean](https://github.com/mindreframer/ex_sqlean),
  which in turn uses [Sqlean](https://github.com/mindreframer/sqlean), but the extension is NOT part of the ExSQlean set.
  Need to investigate with forking and PR.

### Queries

- To get the count of records per genre:

  ```
  select genre.value, count(genre.value) as c from records, json_each(records.genres) genre group by genre.value order by c desc;
  ```

- To get the count of records per artist:

  ```
  select json_extract(artist.value, '$.name') AS name, count(1) as c from records, json_each(records.artists) artist group by name order by c desc;
  ```

  Note that this query would fail to disambiguate artists with the same name - can be fixed by using the artist `musicbrainz_id`.

### CI

See the `.github` folder.

## Favicons

This favicon was generated using the following graphics from Twitter Twemoji:

- Graphics Title: 1f4bd.svg
- Graphics Author: Copyright 2020 Twitter, Inc and other contributors (<https://github.com/twitter/twemoji>)
- Graphics Source: <https://github.com/twitter/twemoji/blob/master/assets/svg/1f4bd.svg>
- Graphics License: CC-BY 4.0 (<https://creativecommons.org/licenses/by/4.0/>)
