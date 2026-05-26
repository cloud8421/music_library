---
id: ML-198
title: store user timezone
status: To Do
assignee: []
created_date: "2026-05-26 21:52"
updated_date: "2026-05-26 22:10"
labels: []
dependencies: []
documentation:
  - doc-28 - ML-198-Research-Store-user-timezone-implementation-routes.md
modified_files:
  - priv/repo/migrations/*_create_settings.exs
  - lib/music_library/settings.ex
  - lib/music_library/settings/setting.ex
  - lib/music_library.ex
  - lib/music_library_web/hooks/get_timezone.ex
  - lib/music_library/records_on_this_day_schedule.ex
  - lib/music_library/worker/schedule_records_on_this_day_email.ex
  - lib/music_library/worker/send_records_on_this_day_email.ex
  - lib/music_library/application.ex
  - lib/music_library/collection.ex
  - lib/music_library_web/live/stats_live/index.ex
  - lib/music_library_web/live/wishlist_live/index.ex
  - lib/music_library_web/live/wishlist_live/show.ex
  - lib/music_library_web/live/maintenance_live/index.ex
  - lib/music_library_web/controllers/collection_controller.ex
  - lib/music_library/listening_stats.ex
  - config/config.exs
  - config/prod.exs
  - test/music_library/settings_test.exs
  - test/music_library/records_on_this_day_schedule_test.exs
  - test/music_library_web/hooks/get_timezone_test.exs
  - test/music_library/worker/schedule_records_on_this_day_email_test.exs
  - test/music_library/worker/send_records_on_this_day_email_test.exs
  - test/music_library/collection_test.exs
  - test/music_library_web/live/stats_live/index_test.exs
  - test/music_library_web/live/wishlist_live/index_test.exs
  - test/music_library_web/live/wishlist_live/show_test.exs
  - test/music_library_web/live/maintenance_live/index_test.exs
  - test/music_library_web/controllers/collection_controller_test.exs
  - test/music_library/listening_stats_test.exs
  - docs/architecture.md
  - docs/production-infrastructure.md
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Currently the user timezone is resolved via a JS hook with every socket connection, and when needed every LiveView can use it. For other operations (e.g. the records on this day email) the system relies on a default timezone setup via an environment variable.

This creates issues where changing the timezone after a flight requires updating the environment variable despite the fact that the browser already provided the updated value.

We should:

1. Maintain a default timezone as an environment variable as a fallback
2. Store the current user timezone the first time the user visits.
3. On every connection, compare the user timezone with the stored one. If they differ, notify the user with a toast that the timezone has been updated, and store the updated timezone.
4. All code paths that need a timezone can resolve from the stored value first, falling back to the default timezone.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 A non-secret persisted settings/preferences store exists for the current timezone; `DEFAULT_TIMEZONE` remains the fallback when no valid stored timezone exists.
- [ ] #2 First connected LiveView visit with a valid browser timezone stores it silently and assigns it to `@timezone`.
- [ ] #3 Subsequent connected LiveView visits compare browser timezone with stored timezone; changes update storage, assign the new value, and show a translated info toast.
- [ ] #4 Missing or invalid browser timezone values do not overwrite a valid stored timezone and do not crash LiveView mounting.
- [ ] #5 Server-side timezone consumers resolve stored timezone first, then fallback default, including records-on-this-day worker/manual send/API default date and ListeningStats fallback.
- [ ] #6 The daily records-on-this-day Oban schedule runs at local 7 AM in the stored timezone, is bootstrapped on app start, and is rescheduled when the stored timezone changes.
- [ ] #7 The email sender job uses an explicit local date and retries independently from the scheduler so future scheduling is not lost on mail delivery failure.
- [ ] #8 Tests cover settings persistence, LiveView hook behavior, scheduler calculations/rescheduling, affected code paths, and invalid timezone handling.
- [ ] #9 Architecture/production docs are updated to reflect the new settings context and dynamic stored-timezone digest scheduling.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Chosen direction

Use Route 1: add a dedicated non-secret settings/preferences persistence layer for the stored user timezone. Because OSS `Oban.Plugins.Cron` loads cron entries statically at boot and runtime cron timezone updates are an Oban Pro `DynamicCron` feature, make the records-on-this-day digest follow the stored timezone via a self-scheduled Oban workflow instead of trying to mutate the Cron plugin at runtime.

## Review amendments incorporated

- Audit every current-date/timezone-sensitive call site, not only the originally listed worker/controller paths.
- Keep `SendRecordsOnThisDayEmail` backward-compatible with already-queued no-arg jobs during rollout.
- Make scheduler uniqueness, replacement, and race/idempotency behaviour explicit and tested.
- Verify scheduler date math across timezones and at least one DST boundary.
- Include full lint validation (`mise run dev:lint`) in addition to targeted tests and `mise run test`.

## Objective alignment

- **Default fallback**: keep `MusicLibrary.default_timezone/0` backed by `DEFAULT_TIMEZONE` and add a stored-first resolver, e.g. `MusicLibrary.current_timezone/0`.
- **First browser visit**: when LiveSocket connect params include a valid browser timezone and no timezone is stored, persist it silently and assign it to the socket.
- **Timezone changes**: on each connected LiveView mount, compare the browser timezone with the stored timezone. If it differs, persist the new value, reschedule the daily digest, and show an info toast.
- **All server/user-local date code paths**: replace default-only or UTC-only timezone lookups where the behaviour is intended to be user-local.
- **Oban schedule follows timezone**: schedule the daily digest as an Oban job at the next local 7 AM for the stored timezone, rescheduling on startup, after each scheduler run, and whenever the stored timezone changes.

## Simplicity and alternatives considered

The simplest viable approach is a small `settings`/`preferences` table plus a self-scheduled Oban scheduler job. This is simpler and safer than dynamic Cron reconfiguration because it uses existing Oban scheduled jobs and avoids Oban Pro-only capabilities.

Rejected/deferred alternatives:

1. **Reuse `MusicLibrary.Secrets`**: faster to implement but semantically wrong because timezone is not secret data and should not live in the encrypted credentials context.
2. **Browser/session-only storage**: does not work for Oban workers or API/controller paths that run without a browser session.
3. **Runtime mutation of `Oban.Plugins.Cron`**: not supported by OSS Oban Cron; would add operational risk. Self-scheduled jobs satisfy the same local-time requirement with less complexity.

## Implementation steps and verification

1. **Add non-secret settings persistence**
   - Add a migration for a small settings/preferences table.
   - Prefer project consistency: use a normal `binary_id` primary key, a non-null string `key`, a non-null string `value`, timestamps, and a unique index on `key`. If the implementation chooses `key` as the primary key instead, document this as an intentional exception to the current binary-id schema convention in `docs/architecture.md`.
   - Add `MusicLibrary.Settings.Setting` schema and `MusicLibrary.Settings` context.
   - Add timezone-specific functions such as `current_timezone/0`, `stored_timezone/0`, and `update_timezone_if_changed/1`.
   - Make `update_timezone_if_changed/1` return explicit outcomes, e.g. `{:ok, :stored}`, `{:ok, :unchanged}`, `{:ok, :changed}`, or `{:error, :invalid_timezone}`, so callers only reschedule/show toasts for real changes.
   - Validate browser-provided timezones against the configured timezone database before persisting.
   - Ensure invalid/corrupt stored values are ignored by resolver functions and never crash callers.
   - Verification before continuing: run the migration up/down locally, add context tests proving fallback, first-store, unchanged, changed, corrupt stored value, and invalid-timezone behaviour.

2. **Add a stored-first timezone resolver**
   - Keep `MusicLibrary.default_timezone/0` as the environment fallback only.
   - Add `MusicLibrary.current_timezone/0` that delegates at runtime to `MusicLibrary.Settings.current_timezone/0`, returning the stored timezone first and falling back to `default_timezone/0`.
   - Avoid compile-time cyclic dependencies: `MusicLibrary.current_timezone/0` should be a runtime delegation/helper only.
   - Ensure invalid/corrupt stored values cannot crash callers; fall back to the default and log a warning if useful.
   - Verification before continuing: unit tests assert resolver behaviour with missing, valid, and invalid stored values.

3. **Update `MusicLibraryWeb.Hooks.GetTimezone`**
   - On disconnected mounts or missing connect params, assign `MusicLibrary.current_timezone/0` and do not write anything.
   - On connected mounts with a valid browser timezone:
     - store silently if this is the first persisted timezone;
     - do nothing if unchanged;
     - update, reschedule the digest, and show a translated info toast if changed.
   - On invalid browser timezone, keep the existing stored/default timezone and do not overwrite it.
   - Confirm that the toast path works with the existing `on_mount` order (`GetTimezone` runs before `ShowToast`). If messages sent during `GetTimezone` are not picked up reliably, adjust hook ordering or use a direct socket-based toast path.
   - Verification before continuing: update `test/music_library_web/hooks/get_timezone_test.exs` to cover no param, first store, unchanged value, changed value with toast, invalid value, and duplicate/concurrent mount safety where practical.

4. **Introduce self-scheduled records-on-this-day scheduling**
   - Add a scheduler/context module, e.g. `MusicLibrary.RecordsOnThisDaySchedule`, that computes the next local run at configured send time (`07:00`) in `MusicLibrary.current_timezone/0`.
   - Move the daily send time into config rather than hard-coding another magic number.
   - Make schedule calculation injectable/testable with an explicit `now` option or helper so tests do not depend on wall-clock time.
   - Add `MusicLibrary.Worker.ScheduleRecordsOnThisDayEmail` as a thin Oban worker that delegates to the scheduler/context: enqueue the email-sending job for the intended local date, then ensure the next scheduler job exists.
   - Update `MusicLibrary.Worker.SendRecordsOnThisDayEmail` to accept an explicit ISO date in args and send for that deterministic local date; keep retries independent from the scheduler.
   - Keep a backward-compatible `perform/1` clause for empty/no-date args during rollout. It should compute the date using `MusicLibrary.current_timezone/0`, send once, and allow existing queued/retryable jobs from the previous implementation to complete safely.
   - Ensure scheduler jobs are unique/rescheduled so only one future scheduler job exists. Cancel/replace only future scheduled scheduler jobs, not executing/retryable scheduler jobs and not email-send jobs.
   - Ensure repeated `ensure_scheduled/0` calls are idempotent and leave exactly one future scheduler job.
   - Verification before continuing: worker/scheduler tests cover next-run calculation before/after 7 AM in multiple timezones, at least one DST boundary, repeated `ensure_scheduled/0`, scheduler `perform/1` enqueuing the send worker and scheduling the next run, no-arg send-worker compatibility, and send worker retries independently on mailer failure.

5. **Bootstrap and reschedule Oban scheduling**
   - Remove the static daily `SendRecordsOnThisDayEmail` entry from `Oban.Plugins.Cron`; keep other Cron jobs unchanged.
   - Add a small supervised bootstrap process after the repos, Oban, and migrations start. It should call the scheduler’s `ensure_scheduled/0`, log failures, and avoid crashing the app if scheduling temporarily fails.
   - Call the same reschedule function after a stored timezone change in `GetTimezone`.
   - Handle multi-tab/multi-LiveView races by relying on the explicit `Settings.update_timezone_if_changed/1` outcome and scheduler idempotency.
   - Verification before continuing: tests or targeted assertions prove startup bootstrap calls scheduling logic; Oban test assertions prove changing timezone replaces the future scheduler job with one scheduled for the new local timezone and does not create duplicates after repeated changes/ensures.

6. **Audit and replace default-only or UTC-only timezone call sites**
   - Audit all current call sites with `rg "default_timezone|Date\\.utc_today|DateTime\\.utc_now|DateTime\\.now!" lib test config docs` before implementation and again before final validation.
   - Update the records-on-this-day worker/scheduler, `MaintenanceLive` manual send path, and `CollectionController.on_this_day/2` default date path to use `MusicLibrary.current_timezone/0`.
   - Fix `ListeningStats` fallback to use a lazy stored-first resolver when no explicit `:timezone` option is supplied.
   - Review `Collection.get_records_on_this_day/1` and its default argument. Prefer explicit dates at call sites; if the default remains, make sure it uses the stored/current timezone rather than UTC when the semantics are user-local.
   - Review LiveViews that derive a current date for user-facing record status or “today” behaviour, including `StatsLive.Index`, `WishlistLive.Index`, and `WishlistLive.Show`; use `socket.assigns.timezone` or `MusicLibrary.current_timezone/0` as appropriate.
   - Keep LiveViews/components that already use `socket.assigns.timezone` as-is after the hook assigns the stored/current value.
   - Verification before continuing: add/update tests proving manual send and API default date use the stored timezone; add `ListeningStats` coverage for the no-option fallback path; update affected Stats/Wishlist tests for local-date semantics or explicitly document any UTC semantics that remain intentional.

7. **Update user-visible text and UI checks**
   - Add gettext-wrapped toast text such as “Timezone updated to %{timezone}.”
   - If the Maintenance page displays timezone information, make sure it distinguishes current stored timezone from the default fallback accurately.
   - Verification before continuing: run gettext extraction/checks as needed and assert the toast/maintenance text in tests.

8. **Documentation and final validation**
   - Update architecture and production docs listed below.
   - Run targeted tests first, then project validation:
     - `mix test test/music_library/settings_test.exs`
     - `mix test test/music_library_web/hooks/get_timezone_test.exs`
     - `mix test test/music_library/records_on_this_day_schedule_test.exs`
     - `mix test test/music_library/worker/schedule_records_on_this_day_email_test.exs`
     - `mix test test/music_library/worker/send_records_on_this_day_email_test.exs`
     - impacted controller/live/context tests
     - `mix format --check-formatted`
     - `mix gettext.extract --check-up-to-date`
     - `mise run dev:lint`
     - `mise run test`
   - Verification before finishing: all targeted tests, lint, and full project test task pass.

## Architecture impact analysis

- **Schemas/tables**: add a non-secret settings/preferences schema and table in `MusicLibrary.Repo`, with a unique/indexed setting key. Prefer preserving the project-wide `binary_id` primary-key convention; document any deliberate exception.
- **Contexts**: add `MusicLibrary.Settings`; add or update a records-on-this-day scheduler/context module for date/schedule calculations.
- **Web hooks/UI**: update `MusicLibraryWeb.Hooks.GetTimezone` to persist/compare browser timezones and emit a toast on changes.
- **Workers/Oban**: add scheduler worker; update email sender worker to accept explicit dates while preserving no-arg compatibility during rollout; remove the static daily Cron entry; keep other Cron jobs unchanged.
- **Supervision tree**: add a lightweight scheduling bootstrap child after repos/Oban/migrations.
- **Controllers/routes**: no route changes; `CollectionController.on_this_day/2` default-date behaviour changes to use stored timezone.
- **LiveViews**: update user-local current-date derivation where currently UTC-only (`StatsLive`, `WishlistLive`) or document intentional UTC semantics.
- **PubSub topics**: no new topics expected.
- **External APIs/services**: no new external API integrations; Mailgun usage remains the existing one-email-per-day digest path.
- **Migrations/deprecation**: migration is additive. Existing `DEFAULT_TIMEZONE` remains supported as fallback; no user-facing deprecation needed.

## Performance profile

- Settings reads/writes are O(1)-style indexed lookups against a single-row/small table.
- Each connected LiveView mount adds at most one settings read and only writes when the browser timezone is first seen or changes.
- Disconnected mounts may also read the stored/current timezone to assign a fallback; this is still a single indexed lookup and acceptable for this single-user app.
- Scheduler operations are constant-size: compute next run, cancel/replace at most one future scheduler job, insert one scheduled job.
- Scheduler uniqueness checks query Oban’s job table by worker/state/args and should remain bounded by the one-scheduler-job invariant; tests should assert duplicate jobs are not produced.
- No N+1 query risk is introduced; no collection/list queries are changed except current-date inputs.
- Memory footprint is negligible; no long-lived large state is required.
- Latency impact is expected to be minimal. Timezone writes happen only on first visit or timezone change.

## Benchmarking requirements

No ongoing benchmark is required because all new work is constant-time/single-row settings access plus one scheduled Oban job per day. If implementation reveals unexpected mount latency or Oban query cost, perform a one-off QueryReporter/SQL check and verify settings lookup/reschedule operations remain below 10 ms locally and do not scan large application tables.

## Cost profile

No new paid resources are introduced. Mailgun cost remains unchanged because the digest is still one scheduled email per day. Storage cost is negligible: one settings row plus one scheduled Oban job. Compute impact is negligible.

## Production Changes

- **Rollout**: standard deployment only. Coolify’s existing post-deploy migration step creates the settings table. No new environment variables are required. `DEFAULT_TIMEZONE` remains the fallback.
- **Initial state**: before the first browser visit stores a timezone, the scheduler uses `DEFAULT_TIMEZONE`. After the browser provides a timezone, the app stores it and reschedules the next digest for that timezone’s local 7 AM.
- **Queued job compatibility**: `SendRecordsOnThisDayEmail` must keep a no-arg compatibility clause for at least this deployment so pre-existing queued/retryable jobs from the old static Cron implementation do not crash. After a later release confirms no old jobs remain, this compatibility path may be removed in a separate cleanup task if desired.
- **Verification after deploy**: confirm a settings row appears after login, confirm the Maintenance page/current timezone is correct, and verify one future `ScheduleRecordsOnThisDayEmail` job exists in Oban for the expected local run time.
- **Rollback**: redeploy the previous version. The additive settings table can remain. If rolling back after a scheduler job has been inserted, cancel future `ScheduleRecordsOnThisDayEmail` jobs through Oban Web or an approved console action so old code does not execute a removed worker; the old static Cron schedule will resume from the rolled-back config.

## Documentation updates

- `docs/architecture.md`: add the Settings schema/context, scheduler worker, bootstrap supervision child, and update the Cron Workers section to describe dynamic stored-timezone scheduling for records-on-this-day. Also document any intentional settings primary-key convention exception if one is introduced.
- `docs/production-infrastructure.md`: update the Oban/daily digest description to explain that `DEFAULT_TIMEZONE` is fallback only and the persisted timezone controls the digest schedule after first browser visit, including rollout compatibility for old no-arg jobs.
- `docs/project-conventions.md`: update only if the implementation establishes a reusable convention for non-secret settings/preferences; otherwise no change needed.
<!-- SECTION:PLAN:END -->
