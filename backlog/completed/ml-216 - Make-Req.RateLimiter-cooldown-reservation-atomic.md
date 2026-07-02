---
id: ML-216
title: Make Req.RateLimiter cooldown reservation atomic
status: Done
assignee:
  - pi
created_date: "2026-06-10 10:39"
updated_date: "2026-06-10 16:11"
labels:
  - fix
dependencies: []
references:
  - lib/req/rate_limiter.ex
  - lib/req/rate_limiter/clock.ex
  - test/req/rate_limiter_test.exs
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: medium
ordinal: 49000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

`Req.RateLimiter.throttle/1` (lib/req/rate_limiter.ex:62-92) performs a non-atomic lookup → sleep → insert sequence on the shared ETS table. With Oban queue concurrency of 3 (music_brainz, discogs, last_fm), concurrent workers can read the same `last_at`, compute identical sleep durations, sleep in parallel, and fire simultaneously — bypassing the per-API cooldown entirely. The system recovers (e.g. MusicBrainz signals rate-limiting via HTTP 503, which snoozes the job), but at the cost of wasted retries and API quota.

The fix is to make slot reservation atomic: each caller atomically claims the next available send slot (`next_at = max(now, current_next_at) + cooldown`) — e.g. via a compare-and-swap loop using `:ets.select_replace/2` (atomic per object) — then sleeps until its claimed slot. The `Req.RateLimiter.Clock` behaviour must be preserved for test clock injection. The ETS table (created in lib/req/rate_limiter.ex:36 with no concurrency flags despite access from all worker queues) should also gain `write_concurrency: true`.

The existing throttle telemetry event (`[:req, :rate_limiter, :throttle]` with sleep_ms) must keep working — it feeds the telemetry dashboard.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Two concurrent callers for the same API name can never both compute a zero/identical wait from the same last_at: each reserves a distinct slot spaced at least cooldown apart
- [x] #2 A test spawns N concurrent throttle calls with the test clock and asserts all reserved slots are spaced >= cooldown
- [x] #3 Existing rate limiter tests (sequential behaviour, zero cooldown bypass, telemetry emission) pass
- [x] #4 ETS table created with write_concurrency: true
- [x] #5 Telemetry event still reports the slept duration

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Change the ETS row semantics from {name, last_at} to {name, next_free_at}. Implement an atomic claim: try `:ets.insert_new(@table, {name, now + cooldown})` for the first caller; otherwise a CAS loop using `:ets.select_replace/2` matching {name, current} and replacing with {name, max(now, current) + cooldown} — select_replace is atomic per object, retry on 0 replacements.
2. The claimed slot start (max(now, current)) minus now is the sleep duration; sleep via the injected Clock and emit the existing [:req, :rate_limiter, :throttle] telemetry with sleep_ms when > 0.
3. Add `write_concurrency: true` to the table options in new/0.
4. Tests in test/req/rate_limiter_test.exs: keep existing sequential/zero-cooldown/telemetry tests green; add a concurrency test spawning N tasks calling throttle for the same name with the test clock, collecting claimed slots, asserting pairwise spacing >= cooldown and no duplicates.
5. Run rate limiter tests, dialyzer (specs change), then precommit.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Pre-flight completed: read architecture and project conventions, reviewed ML-216 plan/acceptance criteria, loaded external API integration, testing, Oban worker, and documentation-update skills. No code changes started; awaiting user approval of the implementation approach.

User approved the recorded implementation plan; proceeding with the scoped rate limiter changes and tests.

Implemented atomic next-slot reservation for Req.RateLimiter using insert_new for first claims and select_replace CAS for existing rows; enabled ETS write_concurrency. Added a synchronized concurrent throttle test that records adapter send slots with the fake clock and verifies uniqueness plus cooldown spacing. Ran `mix format lib/req/rate_limiter.ex test/req/rate_limiter_test.exs && mix test test/req/rate_limiter_test.exs` — 11 tests passed.

Verification update: `mise run dev:precommit` passed all configured checks, including credo, sobelow, gettext, format, full partitioned test suite (1174 Elixir tests/doctests total), unused deps, assets/docs/backlog formatting, Presto tests, and Docker image validation. `mix dialyzer` was also run per the plan; it exited 2 with existing project-wide warnings unrelated to Req.RateLimiter, and a follow-up grep of dialyzer output found no `rate_limiter`/`req/rate` warnings.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Implemented atomic cooldown slot reservation for `Req.RateLimiter`.

Changes:

- Replaced the non-atomic lookup/sleep/insert flow with a reservation model that stores `{name, next_free_at}` in ETS.
- First callers claim a slot with `:ets.insert_new/2`; contended callers use a `:ets.select_replace/2` compare-and-swap loop to atomically advance `next_free_at`.
- Preserved injected clock support and existing throttle telemetry (`[:req, :rate_limiter, :throttle]` with `sleep_ms`).
- Enabled `write_concurrency: true` on the named ETS table.
- Updated rate limiter module docs to describe slot reservation semantics.
- Added tests for ETS write concurrency and synchronized concurrent callers reserving unique cooldown-spaced slots.

Verification:

- `mix format lib/req/rate_limiter.ex test/req/rate_limiter_test.exs && mix test test/req/rate_limiter_test.exs` — 11 passed.
- `mise run dev:precommit` — passed all configured checks, including full partitioned Elixir tests, Presto tests, formatting, credo, sobelow, gettext, unused deps, and Docker image validation.
- `mix dialyzer` — executed per the task plan; exited with existing unrelated project-wide warnings, and follow-up grep found no `Req.RateLimiter`/`req/rate` warnings.

Risks/follow-ups:

- No known follow-up for this task. Dialyzer remains noisy outside this change.

<!-- SECTION:FINAL_SUMMARY:END -->
