---
id: doc-28
title: "ML-198 Research: Store user timezone implementation routes"
type: specification
created_date: "2026-05-26 21:55"
updated_date: "2026-05-26 22:02"
tags:
  - research
  - timezone
  - liveview
---

# ML-198 Research: Store user timezone implementation routes

## Research determination

This task requires research before planning because there is more than one viable persistence route and the chosen route affects multiple architectural layers: LiveView `on_mount`, application configuration, background workers, API/controller behaviour, database schema design, and tests.

## Current state

- The browser sends `Intl.DateTimeFormat().resolvedOptions().timeZone` in LiveSocket connect params from `assets/js/app.js`.
- `MusicLibraryWeb.Hooks.GetTimezone` reads the connect param on each LiveView connection and assigns `:timezone`, falling back to `MusicLibrary.default_timezone/0`.
- The fallback default timezone is configured as `config :music_library, default_timezone: "Europe/London"` and can be overridden by the `DEFAULT_TIMEZONE` runtime environment variable.
- There is no persisted user/account/preferences schema. The app is effectively a single-user authenticated app using a login password, not per-user accounts.
- Existing non-LiveView timezone-sensitive code still uses the default timezone or UTC:
  - `MusicLibrary.Worker.SendRecordsOnThisDayEmail` computes today via `MusicLibrary.default_timezone/0`.
  - `MusicLibraryWeb.MaintenanceLive.Index` manually sends the records-on-this-day email using `MusicLibrary.default_timezone/0`.
  - `MusicLibraryWeb.CollectionController.on_this_day/2` uses `Date.utc_today/0` when the API caller does not pass an explicit date.
  - `MusicLibrary.ListeningStats.cutoff_timestamp/2` has a fallback path intended to use the default timezone when no `:timezone` option is supplied.
- `MusicLibrary.Secrets` already provides encrypted key-value storage for credentials such as the Last.fm session key, but timezone is not secret data.
- Oban cron schedule timezone is currently hard-coded in config (`Europe/London`). Storing a timezone can update the date calculation at worker execution time, but it does not automatically make Oban's cron schedule run at 7 AM in the stored timezone.
- Oban OSS `Oban.Plugins.Cron` loads its crontab statically at boot. Runtime, globally coordinated cron updates are an Oban Pro `DynamicCron` feature, so this project should not rely on mutating `Oban.Plugins.Cron` dynamically.

## Route 1 — Dedicated non-secret settings/preferences context (selected)

Create a small first-class persistence layer for non-secret application/user preferences. Since the app is single-user, this can be either:

- a `settings`/`app_settings` key-value table keyed by setting name, or
- a `user_preferences` singleton table with a `timezone` column.

The context would expose timezone-specific functions such as:

- `current_timezone/0` — returns stored timezone first, then `MusicLibrary.default_timezone/0`.
- `store_timezone/1` or `update_timezone_if_changed/1` — validates and persists browser-provided timezones.
- Optional helper returning whether the value changed so the LiveView hook can decide whether to show the toast.

`GetTimezone` would only write when the browser provided a timezone connect param. First browser-provided value is stored silently; later differences update the store and notify with a translated info toast. LiveViews continue assigning `:timezone`, but from the resolved stored value after reconciliation.

Non-LiveView paths would call the shared resolver instead of reading the environment default directly.

### Pros

- Cleanly models timezone as non-secret application/user state rather than credential material.
- Gives all code paths a single resolver that implements "stored first, environment fallback".
- Easy to validate timezone values before writing or using them.
- Keeps future non-secret preferences out of `Secrets`.
- Works for LiveViews, controllers, workers, and tests.

### Cons

- Requires a migration, schema/context module, and tests.
- Adds one small persisted table for a single setting unless future preferences are added.
- Needs careful handling of disconnected LiveView mount so the default fallback is not written before the browser timezone arrives.

## Route 2 — Reuse `MusicLibrary.Secrets` as a persisted key-value store

Store the timezone under a key such as `user_timezone` or `current_timezone` using the existing encrypted `secrets` table.

### Pros

- Minimal implementation: no migration and no new schema/table.
- Existing context already supports `store/2`, `get/1`, and update-on-conflict behaviour.
- Meets the durability requirement for workers and controllers.

### Cons

- Semantically wrong: timezone is preference/configuration, not secret credential material.
- Adds unnecessary encryption/decryption overhead to a frequently read value.
- Makes `Secrets` responsible for both credentials and non-sensitive preferences, weakening architectural boundaries documented in `docs/architecture.md`.
- Harder to document and reason about future settings.

## Route 3 — Store timezone only in the browser session/cookie/localStorage

Persist the timezone client-side or in the Phoenix session and read it during web requests.

### Pros

- No database migration.
- Keeps browser-derived state near the browser.

### Cons

- Does not satisfy the requirement for background operations such as the records-on-this-day email worker, because Oban jobs do not have a browser session.
- API callers and other server-side operations may not have access to the browser session.
- Server restarts or cookie/session issues can reintroduce fallback-only behaviour.

## Route 4 — Runtime dynamic Oban Cron timezone

Attempt to make the Oban cron plugin's timezone follow the stored timezone so the daily records-on-this-day email runs at the stored local 7 AM rather than at the configured default timezone.

### Pros

- Aligns both the email date calculation and the send time with the stored timezone.

### Cons

- Oban OSS cron configuration is static at boot; dynamic runtime cron updates are an Oban Pro feature.
- Reconfiguring/restarting cron in the application would be more complex and riskier than necessary for a single daily email.
- Operational behaviour would be harder to verify and roll back.

## Final selected route

Use **Route 1** for persistence, plus a **self-scheduled Oban workflow** for the daily digest rather than attempting to mutate `Oban.Plugins.Cron` at runtime.

The schedule design should remove the static daily `SendRecordsOnThisDayEmail` cron entry and replace it with a scheduler that inserts an Oban job at the next local 7 AM according to the stored timezone. The schedule must be bootstrapped on application startup, rescheduled whenever the stored timezone changes, and rescheduled after each scheduler run. The email-sending job should keep retrying independently from the scheduling job so future daily scheduling is not lost when a Mailgun delivery attempt fails.
