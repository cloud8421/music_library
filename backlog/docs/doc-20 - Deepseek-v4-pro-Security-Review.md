---
id: doc-20
title: Deepseek-v4-pro Security Review
type: other
created_date: "2026-05-13 18:27"
---

## Trust boundaries

| Actor                  | Trusted     | Controls                                                             | Source                                                                                                                 |
| ---------------------- | ----------- | -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Web user (browser)     | no          | URL params, form fields, file uploads, LiveView events, HTTP headers | All routes behind `require_logged_in` (except login, health, Last.fm callback, public assets) — `MusicLibraryWeb.Auth` |
| Presto API consumer    | conditional | HTTP Authorization header, query params (`?q=`)                      | Requires Bearer token validated via `Plug.Crypto.secure_compare/2` in `Auth.require_api_token/2` — `api/v1/*` routes   |
| Last.fm OAuth callback | no          | `token` query parameter (validated server-side against Last.fm)      | `LastFmController` `moduledoc` — single-user deployment, token validated via `LastFm.get_session/1`                    |
| Operator / config      | yes         | Application environment variables and config files                   | `config/runtime.exs` and `config/prod.exs` — all secrets originate from env vars                                       |
| MusicBrainz API        | conditional | JSON responses with record/artist metadata                           | `MusicBrainz.API` — data going to HTML is sanitised via MDEx/ammonia; SQL uses parameterised bindings                  |
| Last.fm API            | conditional | JSON responses with scrobble/artist data                             | `LastFm.API` — same sanitisation path                                                                                  |
| OpenAI API             | conditional | Chat responses (markdown), embeddings (float arrays)                 | `OpenAI.API` — responses rendered through MDEx HTML sanitisation                                                       |
| Wikipedia API          | conditional | Plain-text article extracts                                          | `Wikipedia.API` — extracts go through MDEx markdown sanitisation                                                       |
| Brave Search / Discogs | conditional | Image URLs, artist metadata                                          | Rendered through MDEx, or used as `href` targets                                                                       |
| Mailgun (outbound)     | yes         | Outbound email only (no inbound parsing)                             | `MusicLibrary.Mailer` — Swoosh adapter                                                                                 |

## Inventory

| ID  | Location                                                                                                                                                                              | Class                                | Consumes                                                                                                    |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| S1  | `lib/music_library_web/components/notes.ex:164`                                                                                                                                       | Template / `raw()`                   | Note content (user-authored markdown) via `Markdown.to_html()`                                              |
| S2  | `lib/music_library_web/components/core_components.ex:149`                                                                                                                             | Template / `raw()`                   | Debug JSON via `Lumis.highlight!()` — dev/monitoring routes only                                            |
| S3  | `lib/music_library_web/components/search_components.ex:401`                                                                                                                           | Template / `raw()`                   | Record set description via `Markdown.to_html()`                                                             |
| S4  | `lib/music_library_web/components/chat.ex:228`                                                                                                                                        | Template / `raw()`                   | AI-generated assistant message via `Markdown.to_html()`                                                     |
| S5  | `lib/music_library_web/components/chat.ex:243`                                                                                                                                        | Template / `raw()`                   | AI streaming response via `Markdown.streaming_to_html()`                                                    |
| S6  | `lib/music_library_web/live/artist_live/biography.ex:70`                                                                                                                              | Template / `raw()`                   | Wikipedia/Last.fm extract via `Markdown.to_html()`                                                          |
| S7  | `lib/music_library_web/live/artist_live/show.ex:756`                                                                                                                                  | Template / `raw()`                   | Pre-compiled biography HTML (`biography.bio_html`)                                                          |
| S8  | `lib/music_library_web/live/record_set_live/show.ex:275`                                                                                                                              | Template / `raw()`                   | Record set description via `Markdown.to_html()`                                                             |
| S9  | `lib/music_library_web/live/record_set_live/index.ex:446`                                                                                                                             | Template / `raw()`                   | Record set description via `Markdown.to_html()`                                                             |
| S10 | `lib/music_library_web/live/stats_live/top_by_period.ex:118`                                                                                                                          | Resource consumption                 | URL param `period` via `String.to_existing_atom/1`                                                          |
| S11 | `lib/music_library/online_store_templates.ex:87-90`                                                                                                                                   | Template (URL)                       | User-defined `url_template` interpolated with `String.replace` + `URI.encode_www_form`                      |
| S12 | `lib/music_library_web/router.ex` (CSP header)                                                                                                                                        | Validation / CSP                     | Content-Security-Policy with `'unsafe-inline'` scripts and `'wasm-unsafe-eval'`                             |
| S13 | All HTTP client modules (`LastFm.API`, `MusicBrainz.API`, `OpenAI.API`, `Discogs.API`, `BraveSearch.API`, `Wikipedia.API`)                                                            | Network                              | Req default TLS verification (no `:verify_none`)                                                            |
| S14 | `lib/last_fm/api.ex` (log callbacks)                                                                                                                                                  | Shared mutable state / log injection | `sanitize_url/2` redacts API key from logged URLs                                                           |
| S15 | `lib/music_library_web/controllers/archive_controller.ex:21`                                                                                                                          | File operations                      | `send_download` with config-derived database path                                                           |
| S16 | `lib/music_library_web/components/record_form.ex:434`                                                                                                                                 | File operations                      | `File.read!/1` on LiveView upload temp path                                                                 |
| S17 | `lib/music_library_web/live/artist_live/form.ex:209`                                                                                                                                  | File operations                      | `File.read!/1` on LiveView upload temp path                                                                 |
| S18 | `lib/music_library_web/auth.ex:25`                                                                                                                                                    | Cryptography                         | Login password comparison via `Plug.Crypto.secure_compare/2`                                                |
| S19 | `lib/music_library_web/auth.ex:42`                                                                                                                                                    | Cryptography                         | API token comparison via `Plug.Crypto.secure_compare/2`                                                     |
| S20 | `lib/music_library_web/controllers/error_controller.ex:11-16`                                                                                                                         | Validation / resource consumption    | API query params `status`, `muted`, `search`, `limit`, `offset` — parsed to atoms/integers, no raw SQL      |
| S21 | `lib/music_library_web/markdown.ex:103-107`                                                                                                                                           | Template / `raw()` return value      | `process_double_bracket_links/1` — `URI.encode_www_form` on bracket content, then MDEx/ammonia sanitisation |
| S22 | `lib/music_library_web/records_on_this_day_email.ex:59`                                                                                                                               | Template / interpolation             | Email HTML body: record titles and artist names via `html_escape/1`                                         |
| S23 | `lib/music_library/chats.ex:74-77`                                                                                                                                                    | Template / SQL                       | Chat `topic` from first-message content truncated to 80 chars — `String.slice`, no raw SQL context          |
| S24 | All Ecto `fragment()` call-sites in `records/search.ex`, `scrobble_rules.ex`, `maintenance.ex`, `listening_stats.ex`, `collection.ex`, `artists.ex`, `errors.ex`, `records/import.ex` | SQL injection                        | User-supplied or externally-supplied strings used in `fragment()` calls with `^` parameterised bindings     |

## Findings

### F1 — Artist name parameter smuggling in online store URL templates

**Severity:** Low
**CWE:** CWE-88 (Argument Injection)
**Location:** `lib/music_library/online_store_templates.ex:87-90`
**Sinks:** S11

**Trace:**

1. Operator creates an `OnlineStoreTemplate` with `url_template` = `"https://store.example.com/search?q={artist}+{title}"`.
2. Artist names originate from MusicBrainz JSON responses → `MusicBrainz.Release.from_api_response/1` → stored in `records.artists` JSON column → read via `Record.artist_names/1`.
3. `OnlineStoreTemplates.generate_url/2` calls `String.replace(template.url_template, "{artist}", URI.encode_www_form(artists_string))`.
4. `artists_string = Enum.map_join(record.artists, " ", & &1.name)` — this produces a string with literal spaces, not `%20`.
5. `URI.encode_www_form/1` encodes spaces as `+` but does not strip or encode structural characters (`?`, `#`, `&`, `=`) that may already be present in artist names from upstream data.

A MusicBrainz artist whose name contains `&sort=price` (or any URL structural character) causes the generated store URL to carry an unintended query parameter or fragment. For example, an artist named `"Porcupine Tree &sort=price"` would produce a URL where `&sort=price` is interpreted as a separate query parameter by the target store.

**Boundary:** Artist name originates at the MusicBrainz API (trusted but not controlled by the operator). The template is operator-defined and validated via `URI.parse/1` to require `http` or `https` scheme.

**Validation:**

```elixir
# scripts/music_library/online_store_url_smuggling.exs
Mix.install([{:jason, "~> 1.4"}])

# Simulate the generate_url logic
defmodule Smuggle do
  def generate_url(template, artists_string, title) do
    encoded_artists = URI.encode_www_form(artists_string)
    encoded_title = URI.encode_www_form(title)

    template
    |> String.replace("{artist}", encoded_artists)
    |> String.replace("{title}", encoded_title)
    |> String.replace("{format}", URI.encode_www_form("vinyl"))
  end
end

# Benign case
IO.puts("Benign:")
url1 = Smuggle.generate_url(
  "https://store.example.com/search?q={artist}+{title}",
  "Porcupine Tree",
  "In Absentia"
)
IO.puts("  #{url1}")

# Artist name with structural characters
IO.puts("\nArtist name containing '&sort=price':")
url2 = Smuggle.generate_url(
  "https://store.example.com/search?q={artist}+{title}",
  "Porcupine Tree &sort=price",
  "In Absentia"
)
IO.puts("  #{url2}")

# Artist name with fragment
IO.puts("\nArtist name containing '#fragment':")
url3 = Smuggle.generate_url(
  "https://store.example.com/search?q={artist}+{title}",
  "Artist Name #bonus",
  "Album Title"
)
IO.puts("  #{url3}")
```

**Prior art:** No related git commits, issues, or PRs found. The `validate_url_template/1` changeset function was added to prevent non-HTTP schemes, but structural-character encoding in substitution values was not addressed.

**Reach:** Consumer is a single-user personal music-collection application. The `generate_url/2` output is rendered as an `<a href>` on the wishlist detail page. Exploitation requires a malicious upstream data source (MusicBrainz) to serve an artist name with URL structural characters, which is then stored and later interpolated into a store template URL. The impact is link manipulation on an internal-facing wishlist page — an operator clicking a store link could be sent to a URL with additional query parameters or a truncated fragment.

**Rating:** Low — requires an attacker who can control MusicBrainz artist data (unrealistic for a curated database like MusicBrainz) or the operator to manually create a record with a crafted artist name, which is self-inflicted. Impact is limited to query-parameter injection in outbound store links, not to the application itself.

**Suggested fix:** Apply `URI.encode_www_form/1` to the complete query-value portion (i.e. encode the per-artist names individually and join with `+`), or use `URI.encode/2` with `&URI.char_unreserved?/1` to encode all reserved characters including `&`, `?`, `#`, and `=`.

---

## Ruled out

- **S1–S9** (step 3 — sanitisation) — Every `raw()` call site is preceded by `Markdown.to_html/1` (backed by `MDEx.Document.default_sanitize_options()` which wraps ammonia), by `Lumis.highlight!/2` outputting static syntax-highlighted HTML from controlled debug JSON (S2, dev routes only), or by a pre-compiled `biography.bio_html` string that was itself produced through the MDEx pipeline (S7). The `sobelow_skip` annotations at each site correctly identify that the upstream sanitisation has already run. No path from untrusted input reaches `raw()` without traversing ammonia-based HTML filtering.

- **S10** (step 1 — internal) — `String.to_existing_atom/1` only succeeds for atoms already present in the atom table (the `:period` enum values: `:7d`, `:30d`, `:90d`, `:1y`, `:all_time`). If the URL param doesn't match, it raises `ArgumentError`. This does not create new atoms and cannot exhaust the atom table.

- **S12** (step 5 — reach) — `'unsafe-inline'` for scripts/styles is a known tradeoff in Phoenix LiveView applications (morphdom inline patching, colocated hooks). `'wasm-unsafe-eval'` is required by `zxing-wasm` (barcode-detector). The app additionally uses `protect_from_forgery`, CSRF tokens on LiveSocket, and `Content-Type: application/x-www-form-urlencoded` form submissions. The risk surface is comparable to any modern LiveView deployment; no additional CSP bypass vector beyond the standard LiveView surface exists.

- **S13** (step 1 — no boundary crossing) — All HTTP clients use Req's default TLS verification. No `verify: :verify_none`, no `transport_opts` override, no custom `:ssl` configuration found in any API module or config file. The `force_ssl` option in `runtime.exs` is commented out but references a Coolify reverse-proxy TLS terminator in production (documented in `docs/production-infrastructure.md`).

- **S14** (step 3 — validated) — `sanitize_url/2` in `LastFm.API` redacts the API key from log output with `String.replace(url, api_key, "<redacted_api_key>")`. MusicBrainz/OpenAI/BraveSearch/Discogs/Wikipedia API modules log full URLs but do not include API keys in URL paths (they use headers or auth structs, not query params). No API key leakage to logs.

- **S15** (step 1 — config-derived) — `database_path/0` reads `Application.get_env(:music_library, MusicLibrary.Repo)[:database]`, a value set from `DATABASE_PATH` env var in `runtime.exs`. No user input reaches the file path; the `sobelow_skip ["Traversal.SendDownload"]` annotation is correct.

- **S16–S17** (step 2 — Phoenix-managed) — LiveView `allow_upload` provides temporary paths via `entry.client_type`. Phoenix generates these on disk; the caller reads them via `File.read!/1` before storing the content as an Asset (content-addressed by SHA-256 hash). No path traversal possible because the path is assigned by the framework, not derived from user input.

- **S18–S19** (step 3 — validated) — Both login password and API token comparisons use `Plug.Crypto.secure_compare/2`, which is constant-time. No timing side-channel.

- **S20** (step 3 — validated) — `ErrorController` parses all query params into explicit atoms/integers with fallback defaults. The `search` parameter reaches `Errors.list_errors/1` which uses `like/2` with Ecto parameterised bindings (`^"%#{escaped}%"` with LIKE escape). No SQL injection.

- **S21** (step 3 — sanitised) — `process_double_bracket_links/1` extracts content from `[[...]]` brackets, `URI.encode_www_form/1` encodes it for URL query strings, then the full markdown text is processed through MDEx/ammonia. No HTML/URL injection path.

- **S22** (step 3 — sanitised) — `build_html/3` in `RecordsOnThisDayEmail` uses `html_escape/1` (delegating to `Phoenix.HTML.html_escape/1`) on all user-derived values (record titles, artist names). The email body cannot inject HTML from record data.

- **S23** (step 1 — truncated string) — Chat topic is `String.slice(content, 0, 80)` of user input, stored via Ecto changeset. It is displayed in templates where Phoenix auto-escapes HEEx expressions. No raw or unescaped path.

- **S24** (step 3 — validated) — Every `fragment()` call across the codebase uses `^value` parameterised bindings for all user-supplied or externally-supplied strings. The `fts_escape/1` function in `records/search.ex` wraps search terms in double-quoted FTS5 phrase syntax with `""` escaping for literal double quotes, preventing FTS5 query injection. String concatenation (`||`) in `fragment()` calls (e.g., `"records_search_index MATCH 'genres : ' || ?"`) only combines static SQL fragments with `^`-bound values, never dynamic string interpolation. No SQL injection surface identified.
