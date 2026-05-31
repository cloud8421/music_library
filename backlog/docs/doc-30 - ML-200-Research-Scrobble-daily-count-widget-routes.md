---
id: doc-30
title: "ML-200 Research: Scrobble daily count widget routes"
type: specification
created_date: "2026-05-31 18:05"
updated_date: "2026-05-31 18:15"
tags:
  - research
  - stats
  - scrobbles
  - liveview
---

# ML-200 Research: Scrobble daily count widget routes

## Problem

The stats dashboard should show a horizontal bar chart immediately before the existing Scrobble Activity section. The chart should cover the last 30 calendar days and display the count of scrobbled tracks per day.

## Current architecture touchpoints

- `MusicLibraryWeb.StatsLive.Index` renders the `/` stats page. It already imports `MusicLibraryWeb.ChartComponents`, subscribes to `ListeningStats` PubSub updates when connected, and refreshes scrobble-related assigns when new scrobbles arrive.
- `MusicLibrary.ListeningStats` owns listening analytics queries. LiveViews should call this context rather than querying `LastFm.Track` directly.
- `LastFm.Track` persists scrobbles in `scrobbled_tracks`; `scrobbled_at_uts` is an integer Unix timestamp in seconds.
- The existing unique index `scrobbled_tracks_scrobbled_at_uts_title_index` supports range scans on `scrobbled_at_uts`. `EXPLAIN QUERY PLAN SELECT scrobbled_at_uts FROM scrobbled_tracks WHERE scrobbled_at_uts >= ? ORDER BY scrobbled_at_uts ASC` reports a covering index search using that index.
- `MusicLibraryWeb.ChartComponents.horizontal_bar_chart/1` renders horizontal bars with CSS Grid. Project UI conventions prefer CSS Grid charts over SVG.
- The stats page receives the user/browser timezone via `socket.assigns.timezone`; existing top-period stats use this timezone to compute day cutoffs.

Local development data observed during research: `scrobbled_tracks` contains 105,936 total rows and 1,002 rows in the most recent 30 days. This is useful as a realistic order-of-magnitude check for a personal library dashboard read.

## Route A — Context range scan, group by local day in Elixir, render with existing chart component

Add a `ListeningStats` function that accepts `timezone`, `days`, and an optional `current_time` for tests. It computes the local 30-day window, queries only `scrobbled_at_uts` values in that range, converts each timestamp to the user's timezone, groups by `Date`, fills missing days with zero counts, and returns a fixed 30-item list sorted by date. `StatsLive.Index` assigns the result, renders it before Scrobble Activity using `ChartComponents.horizontal_bar_chart/1` or a small stats-specific wrapper, and refreshes it from the existing `listening_stats:update` PubSub path.

Pros:

- Correct for the user's IANA timezone and DST boundaries because grouping happens through Elixir time zone conversion.
- No migration, trigger, background job, cache, or external API required.
- Keeps query ownership in `ListeningStats` and rendering in the stats web layer.
- Reuses the existing CSS Grid chart approach.
- Query is a narrow covering index range scan and returns only one integer column for the last 30 days.

Cons:

- Fetches one row per scrobble in the 30-day window before grouping. This is acceptable for the current app scale but is not constant-time.
- Needs clear tests around timezone boundaries and zero-count days.

Performance profile:

- Runtime: O(n + d), where `n` is scrobbles in the 30-day window and `d = 30`.
- Database: one indexed range scan over `scrobbled_at_uts`, no joins, no N+1 risk.
- Memory: one integer per recent scrobble plus a 30-entry result map/list.
- Expected local scale: approximately 1,000 rows for 30 days based on current dev data.

## Route B — SQL aggregate by UTC calendar day, fill gaps in Elixir

Use SQLite aggregation directly, for example grouping by `date(scrobbled_at_uts, 'unixepoch')`, and fill missing days in Elixir before rendering.

Pros:

- Returns at most 30 aggregate rows to Elixir.
- Simple query shape and no schema change.
- Still uses the `scrobbled_at_uts` range index for the date filter.

Cons:

- Groups by UTC days, not the user's browser timezone. This can move late-night/early-morning scrobbles to the wrong displayed day for the stats page.
- SQLite does not understand IANA timezones or DST transitions, so accurate browser-timezone grouping cannot be expressed directly in SQLite without additional application logic.
- `EXPLAIN QUERY PLAN` for the UTC aggregate still shows a temporary B-tree for `GROUP BY`.

Use this only if the product decision is that UTC days are acceptable for this widget. That would be inconsistent with the current stats page timezone handling.

## Route C — Materialized daily scrobble count table

Create a rollup table such as `daily_scrobble_counts` and maintain it via migration/backfill plus insert/update/delete handling when `scrobbled_tracks` changes. The stats page reads 30 rows from the rollup.

Pros:

- Dashboard read is constant and tiny.
- Could support future long-range daily charts cheaply.

Cons:

- Adds migration, backfill, maintenance logic, and correctness concerns around deletes/updates to scrobble timestamps.
- Still must choose a timezone for the stored day bucket. A UTC rollup has the same product issue as Route B; a local-time rollup would only be correct for one configured timezone and would not match arbitrary browser timezones.
- Over-engineered for a 30-day personal dashboard widget at current data volume.

This route should be deferred unless dashboard reads become measurably slow or daily rollups become a broader analytics requirement.

## Route D — Reuse existing recent activity data or fetch Last.fm again

Either derive daily counts from the current `recent_activity/2` result or call Last.fm for a fresh 30-day activity window.

Pros:

- Reusing existing data sounds superficially simple.

Cons:

- `recent_activity/2` defaults to a 100-track limit, so it can miss older scrobbles within the last 30 days when listening volume exceeds 100 tracks.
- Calling Last.fm duplicates data already persisted locally, adds network latency, consumes API quota/rate-limit budget, and introduces external failure modes to the dashboard.
- This route is less reliable and less consistent than querying local `scrobbled_tracks`.

This route should be rejected.

## Recommended route

Route A is the simplest viable implementation that preserves correctness for the stats page timezone model. It avoids schema churn and external dependencies while using an existing indexed range scan and existing chart infrastructure. Route B is faster in bytes returned but trades away local-day correctness. Route C is operationally heavier than the current objective requires. Route D is incomplete or unnecessarily dependent on Last.fm.

## Open product choices before planning

- Confirm whether the 30-day window should include today plus the previous 29 local calendar days. This is the recommended interpretation.
- Confirm chart ordering: oldest-to-newest reads naturally as a timeline, while newest-first keeps today's activity at the top. The recommended default is oldest-to-newest for a timeline chart.
- Confirm whether the count should count scrobbled track rows. This matches the wording “scrobbled tracks per day” and the existing total scrobble counter semantics.
