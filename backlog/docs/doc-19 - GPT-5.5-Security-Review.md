---
id: doc-19
title: GPT-5.5 Security Review
type: other
created_date: "2026-05-13 18:27"
---

## Trust boundaries

| Boundary                                 | Entrants                                                             | Trusted side                                                      | Notes                                                                                                                   |
| ---------------------------------------- | -------------------------------------------------------------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Anonymous HTTP to Phoenix                | `/public/assets/:transform_payload`, Last.fm callback, static assets | Controllers, contexts, ETS cache, SQLite, native image processing | The public asset route is reachable without session or API token.                                                       |
| Authenticated browser session to Phoenix | LiveViews, controllers, form events, file uploads                    | Context modules, background workers, external API clients         | The app is effectively an operator console; forged LiveView events are still treated as authenticated operator actions. |
| API bearer token to Phoenix              | `/api/v1/*`                                                          | Controllers and contexts                                          | Token is compared server-side before API routes run.                                                                    |
| External providers to app                | MusicBrainz, Last.fm, Discogs, Wikipedia, Brave Search, Mailgun      | API clients, parsers, persistence, renderers                      | Providers are fixed by client configuration except selected image URLs returned to logged-in users.                     |
| Database and local filesystem to app     | SQLite DBs, uploads, backups, release assets, configured DB paths    | Repo, Mix tasks, archive controller, native extensions            | Most file paths are config- or framework-controlled, not direct request parameters.                                     |
| Markdown/HTML to browser                 | User notes, chat output, Wikipedia HTML, formatted debug data        | Phoenix templates, MDEx sanitizer, `raw/1` call sites             | Raw rendering is only safe where upstream HTML is trusted or content is sanitized first.                                |

## Inventory

| ID  | Sink / behavior                                               | Location                                                                                                                                                                                                                                                                   | Boundary                                                      | Security relevance                                                                             |
| --- | ------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| S1  | Asset transform payload decode into `%Transform{hash, width}` | `lib/music_library/assets/transform.ex:43`                                                                                                                                                                                                                                 | Anonymous/public asset request                                | User-controlled JSON controls image lookup and resize dimensions.                              |
| S2  | Asset transform execution and response cache population       | `lib/music_library_web/controllers/asset_controller.ex:12`, `lib/music_library_web/controllers/asset_controller.ex:37`                                                                                                                                                     | Anonymous/public asset request                                | Decoded payload drives image conversion or resize and then stores output in ETS.               |
| S3  | Native libvips resize from untrusted width                    | `lib/music_library/assets/image.ex:19`                                                                                                                                                                                                                                     | Anonymous/public asset request into native image processing   | Width is passed to `Vix.Vips.Operation.thumbnail_buffer/3`.                                    |
| S4  | ETS asset cache with caller-selected transform payload in key | `lib/music_library/assets/cache.ex:39`, `lib/music_library/assets/cache.ex:42`                                                                                                                                                                                             | Anonymous/public asset request into in-memory cache           | Unique payloads can create unique cached image variants.                                       |
| S5  | Brave image download by selected URL                          | `lib/brave_search/api.ex:44`, `lib/music_library_web/live/artist_live/form.ex:234`, `lib/music_library_web/components/record_form.ex:515`                                                                                                                                  | Authenticated browser action to server-side HTTP client       | Potential SSRF sink if exposed to untrusted users.                                             |
| S6  | Discogs artist image download by provider URL                 | `lib/discogs/api.ex:25`                                                                                                                                                                                                                                                    | Discogs provider data to server-side HTTP client              | Provider-supplied URL is fetched server-side.                                                  |
| S7  | MusicBrainz cover art download by URL                         | `lib/music_brainz/api.ex:488`, `lib/music_brainz/api.ex:494`, `lib/music_library/records/enrichment.ex:45`                                                                                                                                                                 | MusicBrainz/Cover Art Archive data to server-side HTTP client | Cover URL can come from persisted release metadata.                                            |
| S8  | Fixed-host upstream API clients                               | `lib/wikipedia/api.ex`, `lib/last_fm/api.ex`, `lib/music_brainz/api.ex`, `lib/brave_search/api.ex`                                                                                                                                                                         | External network                                              | HTTP clients cross the network boundary and parse provider responses.                          |
| S9  | Last.fm XML parsing                                           | `lib/last_fm/session.ex:44`                                                                                                                                                                                                                                                | Last.fm callback token to fixed upstream XML response         | XML parser processes provider-controlled response bodies.                                      |
| S10 | Markdown to HTML with unsafe render enabled and sanitizer     | `lib/music_library_web/markdown.ex:11`                                                                                                                                                                                                                                     | User/provider text to browser HTML                            | `unsafe: true` allows HTML input before sanitizer runs.                                        |
| S11 | Markdown custom link transformation into HTML inline nodes    | `lib/music_library_web/markdown.ex:105`, `lib/music_library_web/markdown.ex:122`                                                                                                                                                                                           | User text to browser HTML                                     | Custom HTML inline rendering can become XSS if escaping is incomplete.                         |
| S12 | Raw HTML render call sites                                    | `lib/music_library_web/components/chat.ex:228`, `lib/music_library_web/components/notes.ex:159`, `lib/music_library_web/live/artist_live/biography.ex:65`, `lib/music_library_web/live/artist_live/show.ex:753`, `lib/music_library_web/components/core_components.ex:137` | Sanitized/trusted HTML to browser                             | `raw/1` and `HTML.raw/1` bypass template escaping.                                             |
| S13 | External links rendered to browser                            | `lib/music_brainz/external_link.ex:24`, `lib/music_library_web/components/core_components.ex:188`                                                                                                                                                                          | Provider URL to browser navigation                            | External URL rendering can enable script URLs, opener attacks, or phishing if not constrained. |
| S14 | Online store URL templates                                    | `lib/music_library/online_store_templates/online_store_template.ex:31`, `lib/music_library/online_store_templates/online_store_template.ex:82`                                                                                                                             | Authenticated configuration to outbound browser URL           | Template output becomes navigable URLs.                                                        |
| S15 | Full-text search SQL and FTS query syntax                     | `lib/music_library/records/search.ex:49`, `lib/music_library/records/search.ex:98`                                                                                                                                                                                         | User search input to SQLite FTS                               | FTS `MATCH` syntax can crash or alter query behavior if not escaped and parameterized.         |
| S16 | Listening stats SQL                                           | `lib/music_library/listening_stats.ex`                                                                                                                                                                                                                                     | Browser filters to SQL                                        | Aggregation queries consume user-selected date/filter values.                                  |
| S17 | Scrobble rules raw SQL builder                                | `lib/music_library/scrobble_rules.ex:495`                                                                                                                                                                                                                                  | Stored rule fields to raw SQL                                 | SQL fragments are assembled for JSON paths and rule targets.                                   |
| S18 | Record set reorder raw SQL                                    | `lib/music_library/record_sets.ex:137`                                                                                                                                                                                                                                     | Authenticated reorder input to SQL                            | Reordering writes positions based on request values.                                           |
| S19 | Error search `LIKE` patterns                                  | `lib/music_library/errors.ex:143`                                                                                                                                                                                                                                          | User search input to SQL                                      | Search strings enter `LIKE` expressions.                                                       |
| S20 | Telemetry raw SQL                                             | `lib/music_library_web/telemetry/storage.ex:203`                                                                                                                                                                                                                           | Runtime telemetry filters to telemetry DB SQL                 | Raw SQL is used against telemetry storage.                                                     |
| S21 | sqlite-vec/vector query fragments                             | `lib/sqlite_vec/ecto/query.ex`, `lib/music_library/records/similarity.ex:261`                                                                                                                                                                                              | Embeddings and limits to SQL fragments/native extension       | Vector search crosses into SQLite extension code.                                              |
| S22 | Query reporter file writes                                    | `lib/music_library/query_reporter.ex:30`                                                                                                                                                                                                                                   | Developer IEx/Tidewave call to filesystem                     | Developer-supplied report path writes query logs.                                              |
| S23 | Upload temp file reads                                        | `lib/music_library_web/live/artist_live/form.ex:201`, `lib/music_library_web/components/record_form.ex:428`                                                                                                                                                                | Phoenix upload temp path to filesystem                        | Server reads temporary upload paths.                                                           |
| S24 | Release Mix tasks network/file writes                         | `lib/mix/tasks/esbuild/release.ex`, `lib/mix/tasks/tailwind/release.ex`, `lib/mix/tasks/sqlean/release.ex`                                                                                                                                                                 | Developer release command to network/filesystem               | Tasks download or write release artifacts.                                                     |
| S25 | Archive DB download                                           | `lib/music_library_web/controllers/archive_controller.ex:7`                                                                                                                                                                                                                | Authenticated browser to configured filesystem path           | Sends configured SQLite database path as a download.                                           |
| S26 | Native SQLite extension loading                               | `lib/music_library/repo.ex:35`, `config/runtime.exs:43`                                                                                                                                                                                                                    | Runtime config to native extension loader                     | Loads extension shared libraries by constructed paths.                                         |
| S27 | Typst document generation                                     | `lib/music_library/records/tracklist_pdf.ex:50`                                                                                                                                                                                                                            | Record metadata to Typst source/PDF engine                    | User/provider text is interpolated into Typst markup.                                          |
| S28 | Cryptographic operations                                      | `config/runtime.exs:59`, `lib/music_library/secrets.ex`, `lib/music_library_web/auth.ex:10`, `lib/last_fm/api/signature.ex`                                                                                                                                                | Secrets, auth credentials, external API protocol              | Sensitive comparison, encrypted storage, and Last.fm signing.                                  |
| S29 | ETS rate limiter                                              | `lib/req/rate_limiter.ex:36`                                                                                                                                                                                                                                               | Internal HTTP clients to in-memory counters                   | ETS stores per-service request timing state.                                                   |

## Findings

### F1: Public asset transforms allow unbounded image resize and cache amplification

**Sinks:** S1, S2, S3, S4  
**Rating:** Medium  
**Confidence:** High  
**CWE:** CWE-400, Uncontrolled Resource Consumption

**Trace:** An unauthenticated request can reach `GET /public/assets/:transform_payload` from `lib/music_library_web/router.ex:61`. `AssetController.show/2` decodes the path segment through `MusicLibrary.Assets.Transform.decode/1` and passes the resulting struct to `cached_get/3` (`lib/music_library_web/controllers/asset_controller.ex:12`, `lib/music_library_web/controllers/asset_controller.ex:37`). `Transform.decode/1` base64-decodes arbitrary JSON and builds `%Transform{hash: params["hash"], width: params["width"]}` without enforcing a schema, integer type, positive range, maximum size, or canonical payload form (`lib/music_library/assets/transform.ex:43`). If `width` is truthy and the asset hash exists, `cached_get/3` calls `Image.resize(asset.content, transform.width, format)`, which passes the value directly into `Vix.Vips.Operation.thumbnail_buffer/3` (`lib/music_library/assets/image.ex:19`). Successful output is stored in ETS by `{payload, format}` (`lib/music_library/assets/cache.ex:39`, `lib/music_library/assets/cache.ex:42`).

**Boundary:** This crosses the anonymous HTTP boundary into native image processing and then into an in-memory cache. Public asset URLs are intentionally generated for email rendering by `RecordsOnThisDayEmail.cover_image_url/2` (`lib/music_library_web/records_on_this_day_email.ex:164`), so a recipient or observer of a valid email image URL can learn a real asset hash and mutate only the `width` field in the unsigned payload.

**Missing validation:** The asset hash is not required to match the application's expected hash shape before lookup, and `width` is not constrained to `nil` or a bounded positive integer. There is also no signature tying the payload to server-generated transform parameters, so attackers can generate unlimited distinct payloads for the same asset.

**Prior art:** `backlog/completed/ml-35 - Harden-the-public-asset-endpoint-against-invalid-payloads.md` and commit `92a36b91` hardened the public asset endpoint against invalid base64, invalid JSON, null hashes, and transform failures. The existing controller tests cover malformed payloads and corrupt image failures, but do not cover non-integer widths, negative widths, very large widths, or cache-key amplification by variant payloads. The prior hardening stopped request crashes, but left resource-control validation open.

**Reachability:** This is reachable without a session or API token. A valid public URL contains enough information to construct additional valid-looking transform payloads for the same asset. Each distinct payload misses the ETS cache and can force a new native resize attempt. When the resize succeeds, the result is cached for a week under the attacker-chosen payload key; when it fails, the process still spends CPU and memory in decode/image handling before returning an error response.

**Validation:** The following reproduction script is provided for local verification only and was not executed during this audit:

```elixir
# scripts/music_library/public_asset_unbounded_width.exs
# Run from the project root with:
#   MIX_ENV=test mix run scripts/music_library/public_asset_unbounded_width.exs
#
# Do not run against production. This demonstrates that widths are accepted
# and processed without an application-level maximum.

Application.ensure_all_started(:music_library)

alias MusicLibrary.Assets
alias MusicLibrary.Assets.{Asset, Cache, Image, Transform}

png =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
  |> Base.decode64!()

hash = Asset.hash(png)

asset =
  case Assets.store(%{content: png, format: "image/png"}) do
    {:ok, %{hash: nil}} -> Assets.get!(hash)
    {:ok, asset} -> asset
  end

for width <- [96, 4096, 12_000] do
  payload =
    %{hash: asset.hash, width: width}
    |> JSON.encode!()
    |> Base.url_encode64(padding: false)

  {:ok, %Transform{width: ^width} = transform} = Transform.decode(payload)

  {usec, result} =
    :timer.tc(fn ->
      Image.resize(asset.content, transform.width, "image/jpeg")
    end)

  case result do
    {:ok, data} ->
      Cache.set(payload, "image/jpeg", data)
      IO.puts("width=#{width} bytes=#{byte_size(data)} ms=#{div(usec, 1000)} path=/public/assets/#{payload}")

    {:error, reason} ->
      IO.puts("width=#{width} error=#{inspect(reason)}")
  end
end

IO.puts("cache_bytes=#{Cache.total_content_size()}")
```

**Rating rationale:** The impact is availability-focused rather than direct data disclosure or code execution. The endpoint is anonymous, the work crosses into native image processing, and the cache key is attacker-influenced, which makes repeated amplification practical. The attacker still needs a valid asset hash from a public image URL, and libvips may fail some extreme inputs before caching output, so Medium is more appropriate than High.

**Fix:** Validate transform payloads before asset lookup or image processing. Require `hash` to match the stored asset hash format, require `width` to be either absent/`nil` or a positive integer in a small allowlist or documented maximum, and reject all other payloads with `{:error, :invalid}`. Consider signing transform payloads, or deriving cache keys from a canonical validated transform struct rather than the raw path segment. Add tests for string widths, negative widths, zero, very large widths, unknown fields, non-canonical payloads, and repeated variant payloads.

## Ruled out

### S5: Brave selected image download

Ruled out at reachability step 5 for the current threat model. `select_image` / `select_cover` events can cause server-side `Req.get/1` of a URL value, and Req redirects are enabled by default. However, these events are behind an authenticated browser session and are part of an operator workflow that intentionally downloads selected remote images. I did not find an unauthenticated path or lower-privileged multi-user boundary that lets an attacker force arbitrary server-side URL fetches. If this app becomes multi-user or exposes these events to untrusted accounts, this should be reclassified as an SSRF candidate and constrained with host/IP allow/deny checks and redirect target validation.

### S6, S7, S8: Provider HTTP clients and fixed upstream requests

Ruled out at source and trust-boundary step 2. MusicBrainz, Last.fm, Wikipedia, Brave Search, and Cover Art Archive requests use fixed API hosts or URLs produced by provider metadata in trusted ingestion flows. I did not find `verify: :verify_none`, shelling out to curl, or request options that disable TLS verification. Discogs and MusicBrainz image downloads do fetch provider-supplied image URLs, but the reachable callers are authenticated/operator-driven ingestion or refresh paths, not anonymous arbitrary URL fetch endpoints.

### S9: Last.fm XML parsing

Ruled out at step 2. The public callback receives a `token`, but the XML body parsed by `LastFm.Session` comes from the fixed Last.fm API endpoint after the app exchanges that token. The parser is not fed raw request body content. The code extracts a small set of expected XML nodes and does not expand the callback token into XML. No direct XXE-style local file or attacker-controlled XML input path was identified.

### S10, S11, S12: Markdown and raw HTML rendering

Ruled out at validation step 3. The app enables MDEx unsafe rendering but immediately configures MDEx sanitization with `MDEx.Document.default_sanitize_options()`. Custom markdown link processing escapes generated URL, title, and text before constructing HTML inline nodes. Raw call sites for notes, chat, and artist biography render the output of `Markdown.to_html/2`, not unsanitized request text. `CoreComponents.pretty_json/1` renders JSON generated by the server for debug display.

Wikipedia biography HTML remains a deliberate trust decision rather than a sanitizer path. Commit `fbc548e9` and `backlog/completed/ml-15 - Sanitize-Wikipedia-bio_html-in-ArtistLive.Show.md` document the decision to trust Wikipedia HTML with a Sobelow skip. The upstream API use is fixed-host and title-encoded. MediaWiki documents the parse/extract API surface for HTML extracts in its API documentation: [API:Get the contents of a page](https://www.mediawiki.org/wiki/API:Get_the_contents_of_a_page) and [API:Query](https://www.mediawiki.org/wiki/API:Query). Because this is not raw user-supplied HTML, I did not rate it as an app-side XSS finding.

### S13, S14: External links and online store templates

Ruled out at step 5. MusicBrainz external links are filtered by known relationship URL patterns before rendering, and rendered links include `target="_blank"` with `rel="noopener noreferrer"`. Online store templates validate that configured URLs use `http` or `https`, then URL-encode artist/title/format placeholder values before substitution. The remaining risk is user/operator configuration quality, not an injection path from untrusted request data to script execution.

### S15, S16, S17, S18, S19, S20, S21: SQL and SQLite extension sinks

Ruled out at validation step 3. The searched SQL sinks use parameter binding for user/provider values. Full-text search terms are escaped before entering `MATCH`; commit `ba256682` fixed special-character FTS crashes by quoting terms, and current code parameterizes the resulting query strings. `ScrobbleRules` builds raw SQL for hardcoded column and JSON-path fragments while binding dynamic values, and `backlog/completed/ml-99 - Raw-SQL-with-string-concatenation-in-ScrobbleRules.md` documents that review as a maintainability/testability concern rather than exploitable SQL injection. Record set reorder, errors search, telemetry queries, and vector similarity queries likewise keep request values in parameters or constrained numeric fields.

### S22, S23, S24, S25: Filesystem reads and writes

Ruled out at step 2. `QueryReporter` writes to a developer-supplied path from IEx/Tidewave and is not reachable from HTTP request parameters. Upload reads use Phoenix-managed temporary upload paths. Release Mix tasks are developer-run commands that download or write predetermined tooling artifacts. `ArchiveController` sends a configured SQLite database path, not a request-controlled file path, and is behind authenticated browser routing.

### S26: Native SQLite extension loading

Ruled out at step 2. Extension paths are constructed from internal OS/architecture detection and literal extension names configured in `config/runtime.exs`. I did not find a request parameter, environment value containing arbitrary path content, or database value that can select an extension filename.

### S27: Typst PDF generation

Ruled out at validation step 3. Tracklist PDF generation interpolates record and track metadata into Typst markup only after passing text through `Typst.Format.escape`. I did not find unescaped metadata entering Typst source in the audited generation paths.

### S28: Cryptographic operations

Ruled out at step 4. Secret storage uses Cloak AES-GCM with a base64-decoded runtime key. Login password and API bearer token comparisons use `Plug.Crypto.secure_compare/2`, which checks byte size and delegates to constant-time comparison for equal-length binaries. Last.fm request signing uses MD5 because that is the Last.fm API signature protocol, not because the app is hashing passwords or authenticating local users with MD5.

### S29: ETS rate limiter

Ruled out at step 1. The ETS table stores per-service request timing for internal HTTP clients. Keys are service atoms supplied by application code, not attacker-controlled terms or unbounded request strings. No direct injection, information disclosure, or cross-request authorization decision depends on this table.
