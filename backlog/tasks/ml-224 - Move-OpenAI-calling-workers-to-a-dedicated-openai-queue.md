---
id: ML-224
title: Move OpenAI-calling workers to a dedicated openai queue
status: To Do
assignee: []
created_date: "2026-06-10 10:41"
updated_date: "2026-06-10 10:57"
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

- [ ] #1 An openai queue (concurrency 3, matching other API queues) exists in the Oban config for dev and prod
- [ ] #2 GenerateRecordEmbedding and PopulateGenres run on the openai queue; no other workers change queues
- [ ] #3 Worker tests assert the queue assignment; chained PopulateGenres → GenerateRecordEmbedding flow still works
- [ ] #4 docs/architecture.md queue and worker tables updated
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
