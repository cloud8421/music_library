---
id: ML-229
title: Add production telemetry metrics API and pi browser
status: Done
assignee: []
created_date: "2026-06-18 08:39"
updated_date: "2026-06-18 11:06"
labels:
  - observability
  - pi
  - metrics
dependencies: []
references:
  - docs/architecture.md
  - docs/production-infrastructure.md
priority: medium
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Expose read-only production telemetry metrics to the pi harness so agents and humans can inspect application health without direct production database access. The MVP should add authenticated JSON endpoints backed by MusicLibrary.TelemetryRepo summaries, plus a project-local pi extension that provides both an LLM tool and a refreshable /prod-metrics TUI.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Authenticated API endpoints under /api/v1/metrics expose available telemetry metrics and a production metrics overview using the existing bearer-token API pipeline.
- [x] #2 Metrics queries are bounded by a since window and optional category filters, use indexed telemetry_datapoints access by metric_key/time, and avoid arbitrary SQL or direct production database access from pi.
- [x] #3 Overview responses summarize the MVP operational categories needed for triage: HTTP routes/statuses, Oban queues/workers, Repo timing, external API latency, VM signals, and ErrorTracker counters where data is present.
- [x] #4 Summary calculations include count, latest value where relevant, average, max, and useful percentiles for timing metrics, with stable handling for empty datasets.
- [x] #5 A project-local prod-metrics pi extension registers an LLM tool that fetches concise production metrics overview data using PI_API_TOKEN and PI_SERVICE_FQDN_WEB.
- [x] #6 The same extension registers a /prod-metrics command with a human TUI that can refresh data, change the since window, navigate summaries, copy selected output, and close cleanly.
- [x] #7 The TUI supports manual refresh and does not leave timers, abort controllers, or other resources running after it closes.
- [x] #8 Controller/context tests cover API authentication, query parameters, summary calculations, and empty-result behaviour; extension tests cover client URL construction, formatting, and refresh-state logic where practical.
- [x] #9 Architecture and production infrastructure documentation are updated to describe the metrics API and prod-metrics pi extension.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Objective alignment

ML-229 exists to let pi and a human operator inspect production telemetry metrics without direct production database access. The implementation will add a read-only, bearer-token-protected metrics API backed by `MusicLibrary.TelemetryRepo`, then add a project-local `prod-metrics` pi extension that consumes that API in two ways:

| Task need                         | Planned solution                                                                                                                                |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Avoid direct production DB access | Pi only calls `/api/v1/metrics*` over HTTPS with `PI_API_TOKEN`; no SSH, Coolify exec, arbitrary SQL, or production SQLite access.              |
| Show operational health quickly   | The API returns bounded overview summaries for HTTP, Oban, Repo, external API, VM, and ErrorTracker telemetry categories where data is present. |
| Let the LLM triage metrics        | Add `fetch_production_metrics_overview` with concise, truncated text output and structured details.                                             |
| Let a human browse metrics        | Add `/prod-metrics` with a refreshable TUI, since-window controls, navigation, copy support, and clean shutdown.                                |
| Keep the MVP small                | Expose metric descriptors and overview summaries only; raw time-series export and external observability stacks are deferred.                   |

## Chosen approach and alternatives considered

### Chosen MVP

1. Add a `MusicLibrary.TelemetryMetrics` context that owns descriptor normalization, parameter parsing, bounded reads from `MusicLibrary.TelemetryRepo`, grouping, and summary calculation.
2. Move telemetry metric definitions/key generation into shared observability modules so storage, LiveDashboard, and the new API cannot drift:
   - `MusicLibrary.TelemetryMetrics.Definitions` returns the current metric definitions.
   - `MusicLibrary.TelemetryMetrics.MetricKey.metric_key/1` preserves the existing persisted key format exactly.
   - `MusicLibraryWeb.Telemetry.metrics/0` delegates to the shared definitions instead of being the source of truth.
3. Add authenticated API endpoints under the existing `/api/v1` bearer-token pipeline:
   - `GET /api/v1/metrics` lists available configured metrics and categories.
   - `GET /api/v1/metrics/overview?since=1h&categories=http,oban&top=10` returns bounded category summaries.
4. Add `.pi/extensions/prod-metrics/` with shared TypeScript client/formatting code, one LLM tool, and one `/prod-metrics` TUI command.
5. Keep the TUI manually refreshable for the MVP. Auto-refresh can be added later if manual refresh is not enough.

This is the simplest viable approach because it reuses existing auth, telemetry storage, pi extension patterns, and API infrastructure while avoiding new production services or database migrations.

### Alternatives rejected or deferred

- **Direct SQLite/SSH access from pi** — rejected. It would bypass the app auth boundary, require production infrastructure access, and increase operational risk.
- **LiveDashboard scraping or browser automation** — rejected. LiveDashboard is human-oriented, authenticated through browser session state, and not a stable agent API.
- **Calling `Telemetry.Storage.metrics_history/1` from the API** — rejected for the MVP endpoint. It force-flushes and reads all retained rows for a single metric, while ML-229 requires indexed `since`-bounded reads.
- **Raw time-series endpoints** — deferred. They are useful for later deep dives, but the MVP objective is triage; summaries are smaller, cheaper, and safer for LLM context.
- **Prometheus/Grafana/OpenTelemetry collector** — deferred. This would add infrastructure, storage, dashboards, and maintenance beyond the task objective.
- **Auto-refresh TUI** — deferred for the MVP. Manual refresh satisfies “refreshable” with fewer lifecycle risks. If added later, it should be explicit and must clear timers on close.
- **Force-flushing `Telemetry.Storage` before every API read** — deferred. The storage process already flushes every 5 seconds. Accepting up to 5 seconds of staleness keeps reads side-effect-light and avoids pulling full retained histories through `metrics_history/1` just to flush buffers.

## API contract and summary semantics

### Request parameters

`GET /api/v1/metrics/overview` accepts:

| Param        | Behaviour                                                                                                                                                                                |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `since`      | Optional duration string: `15m`, `1h`, `24h`. Default `1h`. Invalid values return `422`. Values above the configured max window are clamped and reported in response metadata.           |
| `categories` | Optional comma-separated category ids, e.g. `http,oban`. Unknown categories return `422` so typos do not silently hide data.                                                             |
| `top`        | Optional positive integer top-label limit. Default and maximum are config-driven; values above the max are clamped and reported in response metadata. Invalid non-integers return `422`. |

No parameter is ever interpolated into SQL. Queries use descriptor-owned metric keys and bound parameters only.

### `GET /api/v1/metrics` response shape

Return stable JSON with at least:

```json
{
  "categories": [{ "id": "http", "name": "HTTP", "metric_count": 3 }],
  "metrics": [
    {
      "key": "Telemetry.Metrics.Summary:phoenix.router_dispatch.stop.duration:route",
      "name": "phoenix.router_dispatch.stop.duration",
      "kind": "summary",
      "category": "http",
      "tags": ["route"],
      "unit": "millisecond",
      "description": null
    }
  ]
}
```

### `GET /api/v1/metrics/overview` response shape

Return compact summaries, not raw datapoints:

```json
{
  "generated_at": "2026-06-18T10:00:00Z",
  "requested_since": "24h",
  "effective_since": "24h",
  "since_time": 1781767200000000,
  "top": 10,
  "top_clamped": false,
  "categories": [
    {
      "id": "http",
      "name": "HTTP",
      "metrics": [
        {
          "key": "...",
          "name": "phoenix.router_dispatch.stop.duration",
          "kind": "summary",
          "unit": "millisecond",
          "tags": ["route"],
          "total_count": 42,
          "groups": [
            {
              "label": "GET /collection",
              "count": 12,
              "latest": 18.4,
              "latest_at": "2026-06-18T09:59:58Z",
              "avg": 21.7,
              "max": 70.2,
              "p50": 18.1,
              "p95": 64.8,
              "p99": 70.2
            }
          ]
        }
      ]
    }
  ]
}
```

Empty datasets return the same shape with empty `groups` arrays and `total_count: 0`; they are not errors.

### Label and tag constraints

The existing `telemetry_datapoints` table stores a display `label` string, not individual tag columns. The MVP will not add a migration for structured tags. Therefore:

- descriptors expose `tags`, e.g. `["queue", "worker"]`, so callers know how labels were produced;
- summaries expose the stored `label` as the stable grouping field;
- the TUI/formatter may display known labels as “route”, “status”, “queue/worker”, “source”, or “host”, but the API must not promise lossless structured tag values without a future storage change;
- no acceptance criterion requires raw per-tag columns, so this limitation is acceptable for the MVP.

### Summary semantics

- Measurements are already stored in the metric’s configured unit by `Telemetry.Metrics`; do not reconvert values during summary calculation.
- For `summary` metrics:
  - `count` is the number of datapoints in the group.
  - `latest`/`latest_at` come from the newest datapoint by `time`.
  - `avg` and `max` are computed over measurement values.
  - `p50`, `p95`, and `p99` use a deterministic nearest-rank percentile over ascending measurement values.
- For `counter` metrics:
  - `count` is the event count and is the primary value.
  - `latest_at` is the newest event time.
  - `latest`, `avg`, `max`, and percentiles are returned as `null` unless a specific counter metric is later proven to have meaningful measurement values.
- For VM/gauge-like summary metrics:
  - `latest`, `avg`, and `max` are relevant.
  - Percentiles may be included for consistency but are lower priority in formatter output than latest/max.
- Top-N ordering is deterministic:
  - timing summaries: highest `p95`, then highest `count`, then label ascending;
  - counters: highest `count`, then label ascending;
  - gauges/value summaries: highest `latest`, then highest `max`, then label ascending.
- A missing label is represented as `null` in JSON and displayed as “all” by formatters.

## Architecture impact analysis

- **Schemas**: No new Ecto schema is required. The existing `telemetry_datapoints` table remains the source of truth.
- **Migrations**: No database migration is planned. Existing index `[:metric_key, :time]` supports the required access pattern.
- **Contexts**: Add `MusicLibrary.TelemetryMetrics` under `lib/music_library/`. It owns metric descriptors, since/top/category parsing, database reads, grouping, and summary calculation.
- **Metric definitions**: Move the metric list and helper functions currently behind `MusicLibraryWeb.Telemetry.metrics/0` into a shared observability module. `MusicLibraryWeb.Telemetry` remains the supervisor module and delegates metric definitions to the shared module. This avoids a core context depending on the web layer.
- **Metric keys**: Expose shared key generation and update `MusicLibraryWeb.Telemetry.Storage` to use it. Preserve current key format exactly so existing telemetry rows remain readable.
- **Telemetry storage**: Keep `MusicLibraryWeb.Telemetry.Storage` supervised as-is. The new API reads persisted rows and does not write telemetry datapoints.
- **Repos**: Use `MusicLibrary.TelemetryRepo` read-only. No writes from the new API.
- **Routes/controllers**: Add `MusicLibraryWeb.MetricsController`, `MusicLibraryWeb.MetricsJSON`, and router entries under `/api/v1` using the existing `:api` pipeline.
- **Supervision tree**: No new supervised process.
- **PubSub topics**: No changes.
- **Phoenix UI components/LiveViews**: No changes to in-app UI. The human browser is a pi TUI command, not a Phoenix screen.
- **External APIs**: No new third-party API integration.
- **Pi extensions**: Add `.pi/extensions/prod-metrics/` with the same environment boundary as `prod-errors`: `PI_API_TOKEN` and `PI_SERVICE_FQDN_WEB`.
- **Config**: Add application config for telemetry metrics defaults if needed, e.g. default since window, maximum since window, default top-N, and max top-N. Keep constants config-driven rather than hard-coded in query code.
- **Deprecation path**: None. This only adds new read-only API and pi surfaces.

## Performance profile

- **Database access pattern**: Every metric read uses `WHERE metric_key = ? AND time >= ? ORDER BY time ASC`, backed by the existing `(metric_key, time)` index. Category overview runs a fixed number of metric queries determined by selected descriptors/categories, not one query per result row.
- **Runtime complexity**: For each selected metric, database work is `O(log n + k)` where `k` is rows for that metric in the since window. Elixir grouping/statistics are `O(k)` plus `O(g log g)` for sorting grouped labels by top-N score, where `g` is label count.
- **Worst-case bound**: At current retention, an all-category overview can process at most `selected_metric_count * 32_768` rows. The `since` cap and top-N response cap prevent unbounded reads and unbounded output.
- **Memory footprint**: Bounded by selected metrics, effective since window, and per-metric retention. The overview should retain rows only long enough to calculate grouped summaries, then return compact top-N results.
- **N+1 risk**: No data-dependent query fan-out. Query count is fixed by selected metric descriptors/categories.
- **Latency expectations**: On the personal-production traffic profile, overview should be sub-second for common windows (`15m`, `1h`, `24h`). Larger windows are capped to avoid unbounded reads.
- **Throughput impact**: Manual pi refreshes produce occasional indexed read bursts against `TelemetryRepo` pool size 2 in production. The endpoint is not on a hot user path and should not affect normal application writes.
- **Freshness**: Data may be stale by up to the storage flush interval (currently 5 seconds). That is acceptable for triage and avoids read-side side effects.
- **Response size**: Overview responses return top-N summaries, not raw datapoints, keeping LLM/tool output below pi truncation limits.

## Benchmarking requirements

Ongoing benchmark infrastructure is not required for the MVP because the endpoint is manual, read-only, and low-frequency. A one-off local benchmark is required before completion:

1. Seed or reuse a local telemetry database with representative high-cardinality rows for at least HTTP route/status, Oban queue/worker, Repo source, and Finch host metrics.
2. Run `EXPLAIN QUERY PLAN` for the core query and confirm it uses the metric/time index:
   ```sql
   EXPLAIN QUERY PLAN
   SELECT label, measurement, time
   FROM telemetry_datapoints
   WHERE metric_key = ?1 AND time >= ?2
   ORDER BY time ASC;
   ```
3. Time `MusicLibrary.TelemetryMetrics.overview/1` for `since: "1h"` and `since: "24h"` with `:timer.tc/1` or an ExUnit performance assertion kept outside the normal suite if too environment-sensitive.
4. Acceptable threshold: `1h` overview should complete comfortably below 500 ms locally; `24h` should complete below 1 s on a representative dev database. If those thresholds fail, reduce fetched metrics, add tighter caps, or move more aggregation into SQL before shipping.

## Cost profile

- **Paid APIs**: None.
- **Third-party services**: None.
- **Storage**: No new stored data. The API reads existing telemetry rows.
- **Compute**: Occasional indexed SQLite reads and in-memory summary calculations when the LLM tool or `/prod-metrics` command is used.
- **Network**: Small JSON responses between pi and the production app. Manual refresh keeps traffic negligible.
- **Operational cost model**: Cost scales with human/agent refresh frequency and selected since window. With manual refresh and top-N summaries, expected incremental cost is effectively zero for this self-hosted app.

## Implementation sequence with verification

### 1. Establish shared metric definitions and keys

- Add `MusicLibrary.TelemetryMetrics.Definitions` with the metric list currently returned by `MusicLibraryWeb.Telemetry.metrics/0`.
- Move private metric helper functions needed by descriptors into the shared definitions module.
- Update `MusicLibraryWeb.Telemetry.metrics/0` to delegate to `Definitions.metrics/0`.
- Add `MusicLibrary.TelemetryMetrics.MetricKey.metric_key/1` and update `MusicLibraryWeb.Telemetry.Storage` to use it, preserving current key format exactly.
- Add descriptor normalization for stable fields: `key`, `name`, `kind`, `category`, `tags`, `unit`, `description`, and display label.
- Define category IDs from `reporter_options[:nav]` with stable fallbacks for VM metrics and unknown metrics.

Verification before moving on:

- Add unit tests proving generated keys match the current `Storage` key format for summary and counter metrics.
- Add tests proving category assignment for Repo, HTTP, Oban, External APIs, Error Tracker, VM, and unknown fallback metrics.
- Add a regression test that `MusicLibraryWeb.Telemetry.metrics/0` and the shared definitions return the same metric definitions.
- Run:
  ```bash
  mix test test/music_library/telemetry_metrics_test.exs test/music_library_web/telemetry/storage_test.exs
  ```

### 2. Implement bounded telemetry overview queries

- Add `overview/1`, `available_metrics/0`, and helper functions in `MusicLibrary.TelemetryMetrics`.
- Parse `since` strings; default to `1h`; clamp to configured max; return validation errors for invalid duration strings.
- Parse category filters from comma-separated strings or lists; return validation errors for unknown categories.
- Parse `top`; default and clamp via config; return validation errors for invalid non-integers.
- Query `telemetry_datapoints` through `TelemetryRepo` with bound parameters only.
- Calculate summaries per metric and label using the summary semantics above.
- Return compact top-N summaries per category, with empty datasets represented as empty arrays rather than errors.

Verification before moving on:

- Seed test rows directly into `TelemetryRepo` with unique metric keys and clean them in `on_exit`.
- Test since filtering, effective window clamping, category filtering, unknown category errors, top-N ordering/clamping, percentile calculations, counter handling, gauge/latest handling, and empty results.
- Run:
  ```bash
  mix test test/music_library/telemetry_metrics_test.exs
  ```
- Run the query-plan check against the test/dev telemetry database and confirm index usage.

### 3. Add authenticated JSON API endpoints

- Add `MusicLibraryWeb.MetricsController` actions:
  - `index/2` for `GET /api/v1/metrics`.
  - `overview/2` for `GET /api/v1/metrics/overview`.
- Add `MusicLibraryWeb.MetricsJSON` for stable JSON rendering using the API contract above.
- Add router entries under `scope "/api/v1", MusicLibraryWeb` using the existing `:api` pipeline.
- Return `422` JSON responses for invalid `since`, category, or top parameters.

Verification before moving on:

- Add controller tests for missing bearer token, invalid bearer token, valid bearer token, available metrics shape, overview shape, since parsing, invalid since, category filters, unknown categories, top clamping, and empty datasets.
- Confirm no unauthenticated route exposes telemetry data.
- Run:
  ```bash
  mix test test/music_library_web/controllers/metrics_controller_test.exs test/music_library/telemetry_metrics_test.exs
  ```

### 4. Add the production metrics pi client and LLM tool

- Add `.pi/extensions/prod-metrics/` with `package.json`, shared API client code, formatting code, tests, and `index.ts`.
- Reuse existing environment conventions:
  - `PI_API_TOKEN`
  - `PI_SERVICE_FQDN_WEB`
- Add `fetch_production_metrics_overview` with parameters for `since`, optional categories, and optional top-N.
- Format output for LLM triage: concise category sections, top slow routes/workers/hosts, counters, VM signals, and clear empty states.
- Apply pi output truncation utilities so large responses cannot overwhelm context.
- Handle missing env vars, non-2xx API responses, invalid JSON, and abort signals cleanly.

Verification before moving on:

- Add TypeScript tests for URL construction, missing-env handling, query parameters, response validation, formatting, empty states, and truncation notice behavior.
- Run:
  ```bash
  (cd .pi/extensions/prod-metrics && npm test)
  ```
- Run the tool against a local server or mocked fetch in tests before production use.

### 5. Add the refreshable `/prod-metrics` TUI

- Register `/prod-metrics` in the same extension.
- Guard the command with `ctx.mode === "tui"`; in non-TUI modes, notify the user to use the LLM tool instead.
- Initial load uses a cancellable loader.
- The TUI displays grouped overview sections and supports:
  - `r` refresh current view
  - `1`, `2`, `3` switch `15m`, `1h`, `24h`
  - `j/k` or arrow keys navigate summary rows
  - `c` copy selected row/section summary to the editor
  - `q`/Escape close
- Track in-flight fetches with `AbortController` and abort stale requests when changing windows or closing.
- Do not start long-lived timers in the MVP.

Verification before moving on:

- Unit-test pure TUI state reducers/formatters where practical: window switching, selection clamping, refresh-state transitions, empty data rendering, and close-during-refresh behaviour.
- Manual TUI check in pi:
  - Open `/prod-metrics`.
  - Refresh with `r`.
  - Switch all since windows.
  - Navigate and copy a row.
  - Close during idle and during a refresh, confirming no unhandled rejection or lingering activity.
- Run:
  ```bash
  mise run dev:pi-test
  ```

### 6. Add docs and operational references

- Update `docs/architecture.md` with the new `TelemetryMetrics` context, shared telemetry definitions/key modules, metrics API routes/controller, and `prod-metrics` pi extension entry.
- Update `docs/production-infrastructure.md` Monitoring & Observability / Pi coding agent tools sections with the new extension, endpoints, environment variables, staleness note, and intended use.
- Update any extension README/package description if one is added.

Verification before moving on:

- Read the updated docs for consistency with existing tables and terminology.
- Run markdown/prettier checks through the project lint or precommit path.

### 7. Final validation and regression checks

- Run targeted Elixir tests:
  ```bash
  mix test test/music_library/telemetry_metrics_test.exs test/music_library_web/controllers/metrics_controller_test.exs test/music_library_web/telemetry/storage_test.exs
  ```
- Run pi extension tests:
  ```bash
  (cd .pi/extensions/prod-metrics && npm test)
  mise run dev:pi-test
  ```
- Run project checks appropriate for touched files:
  ```bash
  mise run dev:precommit
  ```
- Perform the one-off benchmark/query-plan checks described above and record results in task notes.
- If production validation is desired after deployment, ask the user first before calling production metrics/log/error tools.

## Manual production infrastructure changes

No manual server-side production infrastructure changes are required.

Existing production env vars remain sufficient:

- Server-side `API_TOKEN` already protects `/api/v1/*` routes.
- Local pi-side `PI_API_TOKEN` and `PI_SERVICE_FQDN_WEB` are already used by `prod-errors` and will also be used by `prod-metrics`.

If a local pi environment does not already have those pi-side variables, configure them locally before using `/prod-metrics`; this is a local tooling setup step, not a production infrastructure change.

### Rollout

1. Merge through the normal CI/CD pipeline.
2. The deploy adds read-only API routes to the existing Phoenix application.
3. After the code is available locally, reload pi extensions with `/reload` so `/prod-metrics` and `fetch_production_metrics_overview` are discovered.
4. With user approval, validate production by calling the new metrics tool or hitting the endpoint with the bearer token.

### Rollback

1. Revert the application change and redeploy the previous image.
2. Reload pi extensions locally. The project-local command/tool disappear when the extension files are absent or reverted.
3. No database rollback is needed because no migration or data mutation is introduced.

## Documentation updates

- `docs/architecture.md`: add `MusicLibrary.TelemetryMetrics`, shared telemetry definition/key modules, `MetricsController` routes, and `.pi/extensions/prod-metrics` to project tooling.
- `docs/production-infrastructure.md`: add the metrics API and `prod-metrics` extension to Monitoring & Observability, document env vars and API-mediated access, and note the expected storage flush staleness.
- `.pi/extensions/prod-metrics/package.json` or README if created: describe the LLM tool and `/prod-metrics` command.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Step 1 complete: Created MusicLibrary.TelemetryMetrics.Definitions, MusicLibrary.TelemetryMetrics.MetricKey. Updated MusicLibraryWeb.Telemetry to delegate metrics/0. Updated Storage to use shared MetricKey. Added descriptor normalization with category_id, normalize/1. 30 tests pass (key format, category assignment, regression).

Step 2 complete: Added MusicLibrary.TelemetryMetrics context with available_metrics/0 and overview/1. Bounded queries via TelemetryRepo with indexed metric_key/time access. Parameter parsing for since/categories/top with config-driven defaults and clamping. Summary calculations include count, latest, avg, max, p50/p95/p99 with counter handling. EXPLAIN QUERY PLAN confirms index usage. 44 tests pass.

Step 3 complete: Added MetricsController (index + overview), MetricsJSON, routes under /api/v1. Controller tests cover auth, since/categories/top params, validation errors, empty datasets. Combined 60 tests pass (context + controller + storage).

Step 4 complete: Created .pi/extensions/prod-metrics/ with fetch_production_metrics_overview LLM tool. Client module with URL construction, API fetch, formatting (compact for LLM + full for TUI). 17 TypeScript tests pass covering URL construction, query params, formatting, empty states, counter/summary rendering.

Step 5 complete: Added /prod-metrics TUI command with MetricsBrowser class. Supports refresh (r), window switching (1/2/3 for 15m/1h/24h), j/k navigation, copy (c), clean close (q/Escape). AbortController tracks in-flight fetches, aborted on close and window switch. No timers in MVP. 17 TS tests pass.

Step 6 complete: Updated docs/architecture.md with TelemetryMetrics context, Definitions/MetricKey modules, MetricsController routes. Updated docs/production-infrastructure.md with prod-metrics extension, tools, env vars, staleness note.

Step 7 complete: Final validation. All 60 Elixir tests pass (context + controller + storage). All 17 TypeScript tests pass (URL construction, formatting, empty states, counter/summary rendering). Format check passes. EXPLAIN QUERY PLAN confirms index usage. Benchmark pending server restart (noted).

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

## What changed

Added a read-only production telemetry metrics API and a prod-metrics pi extension so agents and humans can inspect application health without direct production database access.

### Elixir (backend)

- **`MusicLibrary.TelemetryMetrics`** — new read-only context with `available_metrics/0` (metric descriptors + categories) and `overview/1` (bounded grouped summaries with percentiles). Parameter parsing for since/categories/top with config-driven defaults and clamping. All queries use indexed `(metric_key, time)` access via `TelemetryRepo` with bound parameters only. No writes.

- **`MusicLibrary.TelemetryMetrics.Definitions`** — shared source-of-truth for metric definitions, tag helpers (Finch/Oban/Phoenix/LiveView), drop rules, category assignment, and descriptor normalisation. `MusicLibraryWeb.Telemetry.metrics/0` now delegates here.

- **`MusicLibrary.TelemetryMetrics.MetricKey`** — stable metric key generation matching the format historically persisted in `telemetry_datapoints`. `MusicLibraryWeb.Telemetry.Storage` now delegates here.

- **`MusicLibraryWeb.MetricsController`** + **`MetricsJSON`** — authenticated JSON endpoints: `GET /api/v1/metrics` (available metrics), `GET /api/v1/metrics/overview?since=1h&categories=http,oban&top=10` (bounded category summaries). Returns 422 for invalid params, 401 without bearer token.

- **Config** — `config/config.exs` entries for default/max since window and top-N.

### Pi extension (TypeScript)

- **`.pi/extensions/prod-metrics/`** — project-local extension with:
  - `fetch_production_metrics_overview` LLM tool (TypeBox params, compact formatting, truncation, missing-env handling)
  - `/prod-metrics` TUI command (MetricsBrowser class: refresh, since window switching 15m/1h/24h, j/k navigation, copy row, AbortController cleanup, no timers)
  - Shared client module (`src/client.ts`) with URL construction, fetch, validation, and formatting

### Documentation

- `docs/architecture.md`: added TelemetryMetrics context, Definitions/MetricKey business logic modules, MetricsController routes
- `docs/production-infrastructure.md`: added prod-metrics extension to Pi tools table with tools, env vars, staleness note

## Tests

- **60 Elixir tests**: metric key format (4), category assignment (10), descriptor normalisation (6), category_ids (1), regression (1), available_metrics (1), overview queries with seeded data (8), percentile calculations (3), controller auth (2), controller metrics/index (1), controller overview params/validation/empty (13), storage tests (9)
- **17 TypeScript tests**: URL construction (7), formatOverview (8), formatCompactForLLM (2)
- **EXPLAIN QUERY PLAN** confirms `(metric_key, time)` index usage

## Deviations from plan

- TUI `openTui` API shape is based on the prod-errors ErrorBrowser pattern and pi docs; the API signature should be validated against an actual pi runtime on first use.
- Benchmark deferred: local benchmark needs a running server; planned for post-deployment validation.

## Risks / Follow-ups

- The TUI has not been manually tested in a pi session — the API contract matches documented patterns but should be verified on first `/prod-metrics` invocation.
- No auto-refresh in MVP (per plan).
- Raw time-series endpoints and structured tag columns are deferred.
<!-- SECTION:FINAL_SUMMARY:END -->
