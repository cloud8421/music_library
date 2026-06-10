---
id: doc-34
title: Architecture Review 2026-06-10
type: other
created_date: "2026-06-10 10:55"
tags:
  - architecture
  - audit
---

# Architectural Review: music_library

**Generated**: 2026-06-10 · **Mode**: focus=architecture (6 parallel specialist reviews: boundaries/xref, domain contexts, web layer, Oban, OTP/processes, data layer)
**Method**: every finding below was verified against the current code; findings re-raising decisions settled in Backlog (ML-169.8 et al.) were dropped.

## Resulting tasks

Created from this review on 2026-06-10: ML-209 (A1), ML-210 (A2), ML-211 (A3), ML-212 (B1), ML-213 (B2+B3), ML-214 (C1), ML-215 (C2), ML-216 (D1), ML-217 (D2 cache), ML-218 (D3), ML-219 (E1), ML-220 (E2), ML-221 (F1), ML-222 (C3+C5+E4+F2), ML-223 (E3, decided: document as intentional), ML-224 (C4, decided: dedicated openai queue), ML-225 (B5, decided: migrate to Responses API). B4 (Enrichment naming) was declined — no task.

## Executive Summary

The architecture is in good shape. Boundaries are clean (zero `Repo.*` calls from the web layer, 234 modules with only 61 compile-time edges, no genuine pathological cycles), conventions are applied consistently (thin Oban workers, LiveHelpers extraction, streams everywhere, Facade/API/Config/ErrorResponse integration pattern), and prior audit work (ML-169) visibly paid off. The findings are targeted improvements, not restructurings.

| Area                  | Score  | Status                                                     |
| --------------------- | ------ | ---------------------------------------------------------- |
| Boundaries & coupling | 92/100 | Excellent — 2 domain→web aliases are the only violations   |
| Domain contexts       | 85/100 | Good — ScrobbleRules API surface, one latent search bug    |
| Web layer             | 88/100 | Good — one blocking HTTP call in a LiveView process        |
| Background jobs       | 80/100 | Good — uniqueness gaps, PubSub result leaking into retries |
| OTP & processes       | 85/100 | Good — rate limiter race, ETS flags, migrator ordering     |
| Data layer            | 82/100 | Good — one index-defeating query, blob over-fetching       |

---

## A. Correctness fixes (do these first)

### A1. `Artists.search_by_name_count/1` missing `unaccent()` — count/results mismatch (High)

`lib/music_library/artists.ex:86` filters with `lower(unaccent(artist ->> '$.name'))`; the paired count at `artists.ex:106` filters with `lower(artist ->> '$.name')` only. Searching "bjork" returns rows but counts 0 → pagination built on the pair is inconsistent. Regression-class: ML-141 added accent support, ML-22 was specifically about search/count pair divergence.
**Action**: add `unaccent()` to the fragment at `artists.ex:106` and add a regression test with an accented artist name.

### A2. `scrobbles_for_record_query` defeats all three expression indexes (Medium)

`lib/music_library/listening_stats.ex:624-627` uses `? ->> '$.path'` fragments, but the expression indexes (`20260216115654_add_scrobbled_tracks_indexes.exs`) are built on `json_extract(...)`. SQLite matches expression indexes textually, so `play_count/1` and `get_last_listened_track/1` (record show page, every visit) full-scan `scrobbled_tracks`. This violates the project's own rule: "json_extract() must match expression index text exactly."
**Action**: replace the three `->>` fragments with `json_extract(?, '$....')`.

### A3. `Records.notify_update/1` result returned to Oban — PubSub failure retries whole job (Medium)

`refresh_cover.ex:14`, `record_refresh_music_brainz_data.ex:13`, `populate_genres.ex` return `Records.notify_update(updated_record)` (`:ok | {:error, term()}`) as the job result. A broadcast failure after a successful save retries the entire job, including the external API call.
**Action**: in all three workers, call `notify_update` then return `:ok` explicitly.

---

## B. Boundary & structure

### B1. Two domain modules alias the web layer (Medium)

- `lib/music_library/records/tracklist_pdf.ex:7` → `MusicLibraryWeb.Duration`
- `lib/music_library/worker/send_records_on_this_day_email.ex:4` → `MusicLibraryWeb.RecordsOnThisDayEmail`

Only domain→web dependencies in the codebase; both are formatting/email-building concerns that belong in the domain.
**Action**: move `Duration` to `MusicLibrary.Duration`; move `RecordsOnThisDayEmail` under `MusicLibrary` (it builds a Swoosh email — check its use of verified routes/asset URLs when moving). Update the web call sites.

### B2. ScrobbleRules exposes 10 internal helpers + leaks logging contract (Low/Medium)

`scrobble_rules.ex`: `apply_album_rule/1,2`, `apply_artist_rule/1,2`, `apply_all_album_rules/1,2`, `apply_all_artist_rules/1,2`, `count_album_matches/1`, `count_artist_matches/1` have zero external callers (verified via grep). `log_apply_results/1` is public and piped after `apply_all_rules` at all 3 call sites — including a LiveView, which thereby knows the internal result-tuple shape.
**Action**: make the 10 helpers `defp`; fold `log_apply_results` into `apply_all_rules/0,1` and update the 3 call sites (`listening_stats.ex:65`, `worker/apply_scrobble_rules.ex:16`, `scrobble_rules_live/index.ex:306`).

### B3. `ListeningStats.update/1` calls ScrobbleRules unaliased, inline (Low)

`listening_stats.ex:64-65` pipes through `MusicLibrary.ScrobbleRules.apply_all_rules()` fully-qualified (not in the alias list — the custom Credo alias check evidently missed it). Folding logging per B2 touches this site anyway.
**Action**: add the alias; optionally move rule application to an enqueued `ApplyScrobbleRules` job with the new track list as args to decouple scrobble persistence from rule logic.

### B4. `Records.Enrichment` vs `Collection.Enrichment` naming collision (Low, optional)

Write-side lifecycle ops vs read-side page hydration share a leaf name. **Action**: rename `Collection.Enrichment` (e.g. `Collection.PageHydrator`) — or skip; cosmetic.

### B5. `OpenAI.Completion` legacy path (Low)

Only used by `Records.Enrichment.populate_genres/1`, pinned to `gpt-4o-mini` via the chat-completions endpoint while chats use the Responses API. **Action**: either migrate genre population to the Responses API path or document in `open_ai.ex` why both exist.

---

## C. Background job reliability

### C1. Oban uniqueness gaps (Medium)

- `ImportFromMusicbrainzRelease` (verified: no `unique:`) — sibling `ImportFromMusicbrainzReleaseGroup` has `unique: [period: 300, keys: [...]]`. A re-scanned barcode enqueues a duplicate; the insert hits the `records` unique index, `{:error, changeset}` retries 3× with a MusicBrainz fetch each time.
  **Action**: add `unique: [period: 300, keys: [:release_id]]` and match `{:error, %Ecto.Changeset{}} -> {:cancel, :already_imported}`.
- Five `*All` batch workers — no `unique:`; manual trigger during a cron run double-enqueues every per-record job. **Action**: unique over incomplete states, period 3600.
- `BackfillScrobbledTracks` — re-trigger mid-chain starts a parallel chain (DB-safe via `on_conflict: :nothing`, but duplicates Last.fm calls). **Action**: unique on `to_uts` over incomplete states.

### C2. `SendRecordsOnThisDayEmail` recomputes `today` on retry (Low)

`send_records_on_this_day_email.ex:8` — a delivery failure retried after midnight silently skips that day's email. **Action**: enqueue with the date as an arg (or derive from the job's `inserted_at`) or accept and document.

### C3. `RefreshScrobbles` bypasses `Worker.ErrorHandler` (Low)

`refresh_scrobbles.ex:26-31` re-implements retryable/snooze logic with the atom-based API. **Action**: replace with `ErrorHandler.to_oban_result/1` (LastFm struct already supported).

### C4. `GenerateRecordEmbedding` on `heavy_writes` (concurrency 1) makes OpenAI calls (Low)

Monthly bulk embedding run serializes ~1 job/sec and occupies the queue. **Action**: dedicated `openai` queue, or accept (3 AM, monthly) and note it in the worker.

### C5. Stale moduledoc (trivial)

`apply_scrobble_rules.ex:5` says "every 30 minutes"; cron is every 12h. **Action**: fix the doc.

---

## D. OTP & process

### D1. `Req.RateLimiter` non-atomic check-then-sleep-then-write (Medium)

`lib/req/rate_limiter.ex:70-89`: lookup → sleep → insert. With queue concurrency 3, workers can read the same `last_at`, sleep identical durations, and fire simultaneously — bypassing the cooldown. Recovered via 503-snooze handling, but burns retries/quota.
**Action**: make the reservation atomic — e.g. an `:ets.update_counter`-style monotonic slot reservation (each caller atomically claims `next_at = max(now, last_next_at) + cooldown` and sleeps until its claimed slot), keeping the `Clock` behaviour for tests.

### D2. ETS flags (Low/Medium)

- `assets/cache.ex:40` uses `:compressed` — entries are JPEG/WebP blobs (already compressed); zlib adds CPU on every cache hit on the image-serving hot path. **Action**: drop `:compressed`, add `write_concurrency: true`.
- `req/rate_limiter.ex:36` has no concurrency flags despite access from all worker queues. **Action**: add `write_concurrency: true` alongside the D1 fix.

### D3. `Ecto.Migrator` placed after Oban; restarts on failed migration (Low)

`application.ex`: Oban (child 8) boots before the Migrator (child 9) runs dev migrations — works only because setup scripts migrate beforehand. A failing migration also restarts under `one_for_one` until the supervisor gives up.
**Action**: move the Migrator directly after the repos and give it `restart: :temporary`.

---

## E. Data hygiene & query efficiency

### E1. Blob over-fetching (Low/Medium)

- `collection/enrichment.ex:224-230` loads full `Record` rows (incl. `musicbrainz_data`) for up to a page of records, to read one field. **Action**: `select: %{id: r.id, musicbrainz_data: r.musicbrainz_data}`.
- `records/similarity.ex:261-278` (`find_similar`) selects full `Record` structs; callers render title/cover/artists only. **Action**: project the needed columns.
- `similarity.ex:358-371` + `Records.Batch` stream full rows to enqueue jobs by id. **Action**: add selects.

### E2. `find_similar` runs synchronously in `handle_params` (Low)

`collection_live/show.ex:271-278` — brute-force cosine scan on every patch navigation (including edit-modal open/close). Bounded at personal-collection scale today. **Action**: move to `start_async` with a loading state (pattern already used on `ArtistLive.Show`).

### E3. `notes`/`chats` rows survive record deletion (Low — decide intent)

`Records.delete_record/1` (verified, `records.ex:89-99`) prunes artist info only. Notes/chats are keyed by `musicbrainz_id`, so they also _survive delete + re-import_ — possibly a feature. **Action**: decide: if intentional, document on the `Notes`/`Chats` contexts; if not, add `delete_by_entity/2` calls to the delete path.

### E4. `ArtistInfo` upsert contract undocumented (trivial)

`artists.ex:215-218` replaces only `musicbrainz_data`/`discogs_data` on conflict. **Action**: one comment documenting that wikipedia/lastfm data is refreshed via dedicated paths.

---

## F. Web layer

### F1. MusicBrainz HTTP call inside `handle_info` (Medium)

`scrobble_live/index.ex:145-160` — the rate-limited (1000 ms cooldown) HTTP search runs in the LiveView process; subsequent events queue behind it. `start_async` is the established pattern elsewhere in the codebase.
**Action**: replace `send(self(), {:perform_search, q})`/`handle_info` with `start_async`/`handle_async` (keep the three-case convention).

### F2. `ArtistLive.Show.mount/3` doesn't set `@current_section` (Low)

`artist_live/show.ex:510` — set in `apply_action` instead; deviates from the documented mount convention. **Action**: one-line assign in `mount/3`.

---

## Settled / already tracked (not re-raised)

- **StatsLive.Index sync mount queries**: ML-169.8 reduced 10→3, then follow-up commits `2d8989a8`/`dd24258f` deliberately made latest-record and format/type counters sync again; ML-200 added `daily_scrobble_counts`. Settled decision. The sync `assign_scrobble_activity` in `handle_info` was explicitly accepted in ML-169.8 notes.
- **Dependency cycles**: ML-10/ML-63 already broke the problematic ones; remaining xref cycles are Phoenix wiring, Ecto schema pairs, facade↔config pairs, and the documented Records→Workers data cascade.
- Already in Backlog as To Do: ML-207 (expression-index reindex), ML-204 (SQLite constraints), ML-172 (embedding text quality), ML-169.6 (redundant stream_insert), ML-156 (collection-chat token usage).

## Dropped (insufficient evidence)

- Chat-stream reconnect "ref guard" (a reconnect spawns a new LiveView pid; stale `send_update` to the old pid drops silently).
- FTS5 down-migration trigger claim (reviewer self-contradictory; BEFORE triggers live on `records` and survive FTS table drops).

## What is healthy (keep doing this)

- Web→domain boundary: zero direct Repo access from LiveViews/controllers; contexts own all queries.
- LiveHelpers extraction: Collection/Wishlist index+show share ~95% of logic via config maps; no remaining 3+ duplication.
- Streams used for every list; PubSub subscribe guarded by `connected?/1` everywhere.
- All six API integrations follow Facade/API/Config/ErrorResponse uniformly; `ErrorHandler` is the standard Oban translation in 20+ workers.
- `Batch.run_on_all` accumulates per-record errors instead of failing whole batches; data-layer idempotency (`on_conflict: :nothing`, unique indexes, embedding `:noop` short-circuit) is solid.
- ETS tables owned by the application master (no orphaning); ErrorNotifier telemetry dispatch is non-blocking with bounded throttle state.
