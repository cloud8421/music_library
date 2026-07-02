---
id: ML-213
title: Tighten ScrobbleRules public API and fold logging into apply_all_rules
status: To Do
assignee: []
created_date: "2026-06-10 10:38"
updated_date: "2026-06-10 10:56"
labels:
  - refactor
dependencies: []
references:
  - lib/music_library/scrobble_rules.ex
  - lib/music_library/listening_stats.ex
  - lib/music_library/worker/apply_scrobble_rules.ex
  - lib/music_library_web/live/scrobble_rules_live/index.ex
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: medium
ordinal: 46000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

`MusicLibrary.ScrobbleRules` exposes ten public functions with zero external callers (verified by grep): `apply_album_rule/1,2`, `apply_artist_rule/1,2`, `apply_all_album_rules/1,2`, `apply_all_artist_rules/1,2`, `count_album_matches/1`, `count_artist_matches/1`. They are internal dispatch helpers for `apply_rule/1,2`, `apply_all_rules/0,1` and `count_rule_matches/1`.

Additionally `log_apply_results/1` is public and piped immediately after `apply_all_rules` at all three call sites (lib/music_library/listening_stats.ex:65, lib/music_library/worker/apply_scrobble_rules.ex:16, lib/music_library_web/live/scrobble_rules_live/index.ex:306) — leaking the internal result-tuple shape to callers, including a LiveView. Logging should happen inside `apply_all_rules` itself.

Related cleanup at one of the call sites: `ListeningStats.update/1` references `MusicLibrary.ScrobbleRules` fully-qualified instead of via a top-level alias.

History: ML-92 and ML-105 already refactored this module; this finding is about the post-refactor public surface, not a re-raise.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 The ten internal helpers are private (defp); public API is CRUD plus list_enabled_rules, apply_rule/1,2, apply_all_rules/0,1, count_rule_matches/1
- [ ] #2 apply_all_rules/0,1 logs its results internally; log_apply_results is no longer public; the three call sites drop the explicit pipe
- [ ] #3 ListeningStats aliases ScrobbleRules at the top of the module
- [ ] #4 Tests that exercised helpers directly are rewritten against the public API; full ScrobbleRules test file passes
- [ ] #5 mix credo --strict passes (AliasUsage, module-doc checks)

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. In lib/music_library/scrobble_rules.ex, convert the ten helpers (apply_album_rule/1,2, apply_artist_rule/1,2, apply_all_album_rules/1,2, apply_all_artist_rules/1,2, count_album_matches/1, count_artist_matches/1) to defp; remove public @spec/@doc; move them below public functions per convention. Consider inlining apply_album_rule/apply_artist_rule bodies into apply_rule clauses if that reads better.
2. Make apply_all_rules/0,1 call log_apply_results internally before returning; make log_apply_results private.
3. Update the three call sites to drop the explicit `|> log_apply_results()` pipe: listening_stats.ex:65 (also add `alias MusicLibrary.ScrobbleRules`), worker/apply_scrobble_rules.ex:16, scrobble_rules_live/index.ex:306.
4. Rework tests in test/music_library/scrobble_rules_test.exs that call the now-private helpers to exercise apply_rule/apply_all_rules/count_rule_matches instead; verify log output expectations via ExUnit.CaptureLog where tests asserted logging.
5. Run scrobble_rules + listening_stats + scrobble_rules_live tests, `mix credo --strict`, then precommit.

<!-- SECTION:PLAN:END -->
