---
id: ML-200
title: scrobble count per day widget
status: Done
assignee:
  - cloud
created_date: "2026-05-31 18:02"
updated_date: "2026-05-31 18:59"
labels: []
dependencies: []
documentation:
  - doc-30 - ML-200-Research-Scrobble-daily-count-widget-routes.md
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

In the stats page, right before Scrobble Activity, add a vertical bar chart that shows the last 30 days of scrobble activity as the count of scrobbled tracks per day.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Stats page displays a new scrobble-count-per-day chart immediately before the existing Scrobble Activity section.
- [x] #2 The chart shows exactly 30 local calendar days: today plus the previous 29 days, ordered oldest to newest.
- [x] #3 Each day displays the count of scrobbled track rows for that local day, including zero-count days.
- [x] #4 Daily grouping respects the user's configured/browser timezone rather than UTC-only day boundaries.
- [x] #5 The chart refreshes when new scrobbles are imported and the existing listening-stats update notification is received.
- [x] #6 The implementation has context-level tests for daily count generation, zero-fill behavior, ordering, and timezone boundaries.
- [x] #7 The stats page has LiveView tests proving the chart is rendered in the correct location with expected labels/counts.
- [x] #8 All user-facing chart text is gettext-wrapped and gettext catalogs are updated.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

# Implementation Plan — Route A (revised after plan review)

## Objective alignment

Add a stats dashboard widget immediately before the existing Scrobble Activity section that shows scrobbled track row counts for the last 30 local calendar days. The solution maps directly to the issue by adding a `MusicLibrary.ListeningStats` daily-count query for today plus the previous 29 days, rendering the fixed 30-day result as a horizontal bar chart on `MusicLibraryWeb.StatsLive.Index`, and refreshing the same data through the existing listening-stats PubSub update path.

## Chosen approach and alternatives considered

**Chosen approach: Route A — bounded context range scan + Elixir local-day grouping.** `MusicLibrary.ListeningStats` will own a new public function that accepts `timezone`, `days`, and testable `current_time` options. It will compute the exact local calendar window, query only `scrobbled_at_uts` values from `scrobbled_tracks` within that window, convert timestamps to the requested IANA timezone in Elixir, group by `Date`, fill missing days with zero counts, and return 30 oldest-to-newest entries.

The query must use both bounds for the local window:

- `scrobbled_at_uts >= start_of_first_local_day`
- `scrobbled_at_uts < start_of_tomorrow_local_day`

This keeps the query bounded to exactly today plus the previous 29 local calendar days and prevents future/out-of-window rows from appearing.

This remains the simplest viable approach because it needs no migration, no cache, no background worker, no external API call, and no new infrastructure while preserving correct local-day semantics.

Alternatives evaluated:

- **SQL UTC aggregation:** deferred because SQLite can cheaply group by UTC day, but the widget must respect the stats page timezone model. UTC grouping would misclassify scrobbles around local midnight and DST boundaries.
- **Materialized daily count table:** rejected for now because it adds schema, backfill, write-path maintenance, and timezone-bucket ambiguity for a small 30-day dashboard read.
- **Reuse recent activity or call Last.fm:** rejected because recent activity is capped and can miss tracks in busy 30-day windows; Last.fm calls duplicate local data, add latency, and consume external API/rate-limit budget.

Research details are captured in `doc-30 - ML-200-Research-Scrobble-daily-count-widget-routes.md`.

## Architecture impact analysis

- **Schemas:** no schema changes. `LastFm.Track` remains unchanged; counts are derived from existing `scrobbled_tracks.scrobbled_at_uts` rows.
- **Contexts:** add a public analytics function to `MusicLibrary.ListeningStats`. The LiveView must not query the database directly.
- **Database/indexes:** use the existing unique index on `[:scrobbled_at_uts, :title]` for an indexed bounded range scan. No migration is expected unless `EXPLAIN QUERY PLAN` shows the final bounded range query is not using that index.
- **LiveView/UI:** update `MusicLibraryWeb.StatsLive.Index` to assign/render the new chart immediately before `.scrobble_activity`. Add a stable wrapper id such as `id="daily-scrobble-counts"` so tests can verify ordering relative to the existing `id="scrobble-activity"` section.
- **Components:** prefer reusing `MusicLibraryWeb.ChartComponents.horizontal_bar_chart/1`; add only a small stats-specific wrapper if needed for labels, empty state, or accessible text.
- **PubSub:** reuse existing `ListeningStats.subscribe/0` topic and `%{track_count: n}` messages. Update the existing refresh helper so daily counts refresh with the total count and recent activity on nonzero updates.
- **Routes:** no route changes.
- **External APIs:** no Last.fm/API calls for this widget; data comes from local persistence.
- **Supervision tree/workers:** no supervision or Oban worker changes.
- **Gettext:** new visible strings must be wrapped and catalogs updated.

## Performance profile

- **Runtime complexity:** O(n + d), where `n` is scrobbles in the exact 30-day local window and `d = 30` fixed output days.
- **Database query pattern:** one indexed bounded range scan selecting only `scrobbled_at_uts`, ordered ascending. No joins and no per-day query loop, so no N+1 risk.
- **Expected SQL shape:** `SELECT scrobbled_at_uts FROM scrobbled_tracks WHERE scrobbled_at_uts >= ? AND scrobbled_at_uts < ? ORDER BY scrobbled_at_uts ASC`.
- **Memory footprint:** one integer per scrobble in the recent window plus a 30-entry result list/map. Current local data observed during research had about 1,002 scrobbles in the last 30 days.
- **Latency/throughput:** expected dashboard impact is small for a personal collection app. The query runs on page mount and when new scrobbles are imported via existing PubSub notifications.
- **Failure mode:** if the query fails unexpectedly, it should fail like existing synchronous stats assigns unless implemented as async; do not introduce external-service failure paths.

## Benchmarking requirements

No ongoing benchmark is required before implementation because the query is a bounded 30-day indexed range scan and current observed row volume is modest.

One-off validation is required during implementation:

1. Run `EXPLAIN QUERY PLAN` for the final bounded SQL shape and confirm SQLite uses `scrobbled_tracks_scrobbled_at_uts_title_index` or an equivalent covering/range index for `scrobbled_at_uts >= ? AND scrobbled_at_uts < ?`.
2. Use development data or seeded test data to confirm the number of fetched rows is limited to the exact local 30-day window.
3. If local or production-like data shows the query is slow enough to affect dashboard rendering, stop and revisit Route C rather than adding an ad hoc cache.

Acceptable threshold for this task: one dashboard read should perform a single indexed bounded range query for daily counts and should not introduce any query loop proportional to 30 days.

## Cost profile

No paid resources are consumed. The implementation uses local SQLite data and existing LiveView rendering. It does not call Last.fm or any other external API, does not increase storage, and does not require additional compute services.

## Production Changes

No manual production changes are expected.

- **Environment variables:** none.
- **Service provisioning:** none.
- **Database migrations:** none expected.
- **DNS/firewall:** none.
- **Rollout:** deploy the code normally through the existing release pipeline.
- **Rollback:** revert the application code if the widget causes issues; no data rollback is required because no schema or persistent data changes are planned.

## Documentation updates

- `docs/architecture.md`: update only if the implementation adds a new named component/module or materially changes the stats dashboard/context map. A small function in `ListeningStats` and markup in `StatsLive.Index` may not require an architecture update unless a new component module is introduced.
- `.agents/skills/*`: no updates expected.
- README/API docs: no updates expected; this is an internal dashboard UI feature.
- Gettext catalogs: update `priv/gettext/default.pot` and locale files after adding user-facing strings.

## Sequential implementation steps with verification

1. **Add the context function in `MusicLibrary.ListeningStats`.**
   - Implement a public function such as `daily_scrobble_counts/1` or `scrobble_counts_by_day/1` with options for `timezone`, `days: 30`, and `current_time`.
   - Prefer returning a fixed list of maps such as `%{date: Date.t(), count: non_neg_integer()}` ordered oldest to newest.
   - Compute calendar boundaries by first shifting `current_time` into the supplied timezone, deriving `today` from that local time, then using `Date.add/2` for calendar-day math. Do not subtract fixed 24-hour second intervals to derive local dates because DST boundaries matter.
   - Compute `first_date = Date.add(today, -(days - 1))` and `tomorrow = Date.add(today, 1)`.
   - Convert local midnights for `first_date` and `tomorrow` to Unix timestamps in the supplied timezone; use those as the lower and upper SQL bounds.
   - Query only `scrobbled_at_uts` values where `scrobbled_at_uts >= start_uts and scrobbled_at_uts < end_uts`, ordered ascending.
   - Convert each returned timestamp to the supplied timezone, group by local `Date`, count rows, fill all 30 dates with zeroes, and return oldest-to-newest entries.
   - Verification before moving on: add/run focused context tests for exact 30-day length, oldest-to-newest order, zero-filled missing days, counting rows rather than distinct timestamps, exclusion before the window, exclusion at/after tomorrow, inclusion on today, and timezone boundary behavior.

2. **Validate the SQL query shape.**
   - Inspect the generated SQL or equivalent query and run `EXPLAIN QUERY PLAN` against SQLite.
   - Verification before moving on: confirm the plan uses the existing `scrobbled_at_uts` range/covering index and does not perform a full table scan or 30 separate queries.

3. **Render the widget on `StatsLive.Index`.**
   - Assign the daily-count data during mount using the user timezone from the socket.
   - Add a section immediately before the existing `.scrobble_activity` call.
   - Wrap the section with a stable id such as `daily-scrobble-counts` so tests can assert it appears before `scrobble-activity`.
   - Reuse `ChartComponents.horizontal_bar_chart/1` where practical, with labels suitable for local dates and counts as values. If a small wrapper is needed, keep it in the stats/chart component layer and follow project UI conventions: gettext strings, paired dark-mode classes, CSS Grid charting, and accessible text/labels.
   - Verification before moving on: run the focused stats LiveView test and inspect rendered HTML ordering to confirm the daily chart section precedes Scrobble Activity.

4. **Refresh the widget when scrobbles update.**
   - Extend the existing `assign_scrobble_activity/1` refresh path or equivalent so `%{track_count: n}` PubSub updates refresh total scrobbles, recent activity, and daily counts together.
   - Preserve the existing `%{track_count: 0}` no-op behavior unless there is a product reason to reload on zero inserted tracks.
   - Verification before moving on: add/run a connected LiveView test that inserts or broadcasts a nonzero listening-stats update and proves the chart data/counts change after the update is received.

5. **Update gettext catalogs.**
   - Wrap new headings, empty-state text, accessible labels, and any date/count labels requiring text in `gettext/1` or `ngettext/3` as appropriate.
   - Run gettext extraction/merge.
   - Verification before moving on: run the gettext up-to-date check or the project task/check that covers it.

6. **Run focused and relevant verification.**
   - Run `mix test test/music_library/listening_stats_test.exs`.
   - Run `mix test test/music_library_web/live/stats_live/index_test.exs`.
   - Run formatting and relevant project verification tasks identified in `docs/available-tasks.md`, such as `mise run dev:lint` or the conditional precommit task, before finalizing implementation.
   - Verification before moving on: all focused tests pass, formatting is clean, and no gettext drift remains.

7. **Visual verification.**
   - With the dev server running, open the stats page and capture screenshots after the chart is visible.
   - Verify both light and dark mode if custom colors/classes are added or changed.
   - Verification before completion: chart appears immediately before Scrobble Activity, has 30 bars/rows, remains readable at common viewport widths, excludes future/out-of-window rows, and dark-mode colors are paired/correct.

Review-fix pass: strengthen Stats LiveView tests for the daily scrobble chart by (1) asserting the rendered row count is tied to the expected date label instead of matching any descendant text, and (2) adding a connected LiveView PubSub refresh test that mounts the page, inserts a new unique scrobble afterwards via `ListeningStats.update/1`, and verifies the daily chart updates without reload. Then run focused tests and formatting.

Requested UI revision: add a reusable `vertical_bar_chart/1` component to `MusicLibraryWeb.ChartComponents` using CSS Grid and paired light/dark styling, then switch the Daily Scrobbles widget in `StatsLive.Index` from `horizontal_bar_chart/1` to the new component. Preserve existing label/value functions and update LiveView tests only if the DOM structure changes. Verify with focused tests, formatting, Credo, and browser preview on port 4003.

Small visual refinement: update `vertical_bar_chart/1` day labels from 45-degree angled labels to 90-degree rotated labels centered below each column, then rerun focused tests/formatting and quick browser verification.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Updated plan and research doc after the existing chart component was renamed from `vertical_bar_chart/1` to `horizontal_bar_chart/1`, so implementers should use the corrected component name.

Steps 1-4 complete: context function `daily_scrobble_counts/1`, widget in StatsLive.Index before scrobble-activity, PubSub refresh wired via assign_scrobble_activity/1. Context tests (6) pass. LiveView tests (3) pass.

Review found the context/query implementation is sound, but the LiveView test suite does not exercise the post-mount `%{track_count: n}` refresh path and has a weak count assertion that can pass on date-label text.

Review fixes complete: the LiveView test now pairs the expected date label with the adjacent chart value via LazyHTML instead of matching arbitrary descendant text, and a new connected LiveView test verifies `ListeningStats.update/1` broadcasts a nonzero update that refreshes the daily chart after mount.

Credo follow-up: replaced `length(...) == literal` assertions in `daily_scrobble_counts/1` tests with `Enum.count_until/2`; full `mix credo --strict` now passes.

User reviewed the horizontal chart and requested replacing it with a vertical bar chart component for the daily scrobble widget.

User requested the vertical chart day labels rotate 90 degrees and align centered under each column.

Vertical label refinement follow-up: labels are cropped after rotating to 90 degrees, so move the rotated label baseline down within its slot and verify again.

Moved the 90-degree day labels down and centered them under each column by giving the rotated label its own larger relative slot and centering with absolute positioning; focused tests, compile, format check, and component Credo pass.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

## What changed

Added a "Daily Scrobbles" vertical bar chart to the Stats page showing scrobble count per day for the last 30 local calendar days, positioned immediately before the existing Scrobble Activity section.

### New context function (`MusicLibrary.ListeningStats.daily_scrobble_counts/1`)

- Accepts `timezone`, `days` (default 30), and `current_time` (testable)
- Computes local calendar boundaries using `Date.add/2` (DST-safe, not fixed 24-hour intervals)
- Queries `scrobbled_tracks` with a bounded range scan on `scrobbled_at_uts` using the existing `scrobbled_tracks_scrobbled_at_uts_title_index` covering index
- Groups timestamps by local `Date` in Elixir, fills zeroes for days with no scrobbles
- Returns 30 `%{date: Date.t(), count: non_neg_integer()}` entries, oldest to newest

### Stats page widget (`MusicLibraryWeb.StatsLive.Index`)

- Section titled "Daily Scrobbles" (gettext-wrapped), wrapped in `#daily-scrobble-counts`
- Uses new `ChartComponents.vertical_bar_chart/1` with emerald bars and local date labels (`%b %d`)
- Day labels are rotated 90 degrees and centered below each column
- Refreshes through the existing `assign_scrobble_activity/1` path when PubSub receives `%{track_count: n}` for nonzero imports

### Tests

- Context tests cover 30-day length, ordering, zero-fill, boundary exclusion/inclusion, row counting (not distinct timestamps), and timezone grouping
- LiveView tests cover section rendering, DOM order before Scrobble Activity, precise date/count pairing, and post-mount PubSub refresh after `ListeningStats.update/1`

### Verification

- `mix test test/music_library/listening_stats_test.exs test/music_library_web/live/stats_live/index_test.exs` — 65 passed
- `mix test test/music_library_web/live/stats_live/index_test.exs` — 15 passed after vertical-label refinement
- `mix format --check-formatted lib/music_library_web/components/chart_components.ex`
- `mix compile --warnings-as-errors`
- `mix gettext.extract --check-up-to-date`
- `mix credo --strict` / `mix credo --strict lib/music_library_web/components/chart_components.ex`
- Browser preview on port 4003 verified placement, 30 rendered chart bars/labels, responsive horizontal scrolling, light/dark appearance, and no console errors

### Risks / follow-ups

- No production changes or migrations needed
- Query currently loads the bounded 30-day timestamp window into memory; if the app ever has very high recent scrobble volume, revisit a materialized daily-count table.
<!-- SECTION:FINAL_SUMMARY:END -->
