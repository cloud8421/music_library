---
id: ML-224
title: Move OpenAI-calling workers to a dedicated openai queue
status: Done
assignee:
  - pi
created_date: "2026-06-10 10:41"
updated_date: "2026-06-10 15:36"
labels:
  - oban
dependencies: []
references:
  - lib/music_library/worker/generate_record_embedding.ex
  - lib/music_library/worker/populate_genres.ex
  - config/config.exs
  - config/prod.exs
  - docs/architecture.md
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: medium
ordinal: 57000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

`GenerateRecordEmbedding` and `PopulateGenres` run on the `heavy_writes` queue (concurrency 1) but make outbound OpenAI HTTP calls. The queue's concurrency-1 design exists to serialize DB-intensive work; coupling API latency to it means the monthly `RecordGenerateAllEmbeddings` run processes roughly one embedding per second and occupies `heavy_writes` (blocking RepoVacuum, RepoOptimize, ApplyScrobbleRules) for the duration. Every other API-calling worker already runs on a per-API queue (music_brainz, discogs, wikipedia, last_fm) with pacing enforced at the Req layer.

Maintainer decision (2026-06-10): add a dedicated `openai` queue rather than documenting the serialization. The OpenAI Req client's 250 ms rate-limit cooldown governs pacing, matching the other API queues' pattern (queue concurrency for isolation, Req.RateLimiter for politeness).

Note: PopulateGenres chains into GenerateRecordEmbedding — confirm the chained enqueue needs no change beyond the queue attribute.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 An openai queue (concurrency 3, matching other API queues) exists in the Oban config for dev and prod
- [x] #2 GenerateRecordEmbedding and PopulateGenres run on the openai queue; no other workers change queues
- [x] #3 Worker tests assert the queue assignment; chained PopulateGenres → GenerateRecordEmbedding flow still works
- [x] #4 docs/architecture.md queue and worker tables updated

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Add `openai: 3` to the Oban queues in config/config.exs (confirm prod uses the same queue list; adjust config/prod.exs if queues are defined per-env).
2. Change `queue: :heavy_writes` to `queue: :openai` in GenerateRecordEmbedding and PopulateGenres.
3. Trace the PopulateGenres → GenerateRecordEmbedding chain (Records.Enrichment / Similarity enqueue path) to confirm nothing hardcodes the queue name at enqueue time.
4. Update worker tests: assert_enqueued with queue: :openai where queue is asserted; run both worker test files.
5. Update docs/architecture.md: queues table, on-demand workers table rows for the two workers.
6. Run precommit.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Starting implementation. Adding `openai` queue (concurrency 3) and moving GenerateRecordEmbedding + PopulateGenres to it.

Added `openai: 3` to queues in config/config.exs. Changed GenerateRecordEmbedding and PopulateGenres to `queue: :openai`. Verified PopulateGenres → GenerateRecordEmbedding chain doesn't hardcode queue at enqueue (uses `GenerateRecordEmbedding.new()` + `Oban.insert()`). Updated populate_genres_test.exs assert_enqueued to include `queue: :openai`. Both test files pass (7/7).

Ran precommit: Credo ✅, Sobelow ✅, 1169 tests passed, formatting ✅. Fixed prettier formatting on task file.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

## Changes

Added a dedicated `openai` queue (concurrency 3) for OpenAI API-calling workers, matching the existing pattern where every API has its own queue with pacing enforced by `Req.RateLimiter`.

### Files modified

- **`config/config.exs`**: Added `openai: 3` to the Oban queues list (prod inherits queues from this config; no prod override needed)
- **`lib/music_library/worker/generate_record_embedding.ex`**: Changed `queue: :heavy_writes` → `queue: :openai`
- **`lib/music_library/worker/populate_genres.ex`**: Changed `queue: :heavy_writes` → `queue: :openai`
- **`test/music_library/worker/populate_genres_test.exs`**: Added `queue: :openai` to `assert_enqueued` for the chained `GenerateRecordEmbedding` job
- **`docs/architecture.md`**: Added `openai` row to Queues table, updated `PopulateGenres` and `GenerateRecordEmbedding` queue in On-Demand Workers table

### What was verified

- The PopulateGenres → GenerateRecordEmbedding chain uses `GenerateRecordEmbedding.new()` + `Oban.insert()` in `Similarity.generate_embedding_async/1` — no hardcoded queue at the enqueue site, so the queue change is self-contained in the worker definitions
- `RecordGenerateAllEmbeddings` (bulk orchestrator) stays on `heavy_writes` — it doesn't call OpenAI directly; the individual jobs it enqueues flow to `openai`
- No other workers changed queues

### Tests

Both worker test files pass (7/7). Full precommit suite passes: Credo (no issues), Sobelow, 1169 tests across 4 partitions, formatting (Elixir, assets, docs, backlog).

<!-- SECTION:FINAL_SUMMARY:END -->
