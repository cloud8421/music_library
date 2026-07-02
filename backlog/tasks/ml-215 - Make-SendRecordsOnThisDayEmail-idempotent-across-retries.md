---
id: ML-215
title: Make SendRecordsOnThisDayEmail idempotent across retries
status: To Do
assignee: []
created_date: "2026-06-10 10:39"
updated_date: "2026-06-10 10:56"
labels:
  - oban
  - fix
dependencies: []
references:
  - lib/music_library/worker/send_records_on_this_day_email.ex
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: low
ordinal: 48000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

`SendRecordsOnThisDayEmail.perform/1` (lib/music_library/worker/send_records_on_this_day_email.ex:8) computes `today` inside the job. If the 7 AM delivery fails and Oban retries after midnight, the retry computes the next day's date: that day's anniversary email is silently skipped and no record of the miss exists.

The date should be fixed at enqueue time. Since the job is cron-enqueued without args, the cleanest source is the job's own insertion timestamp (`%Oban.Job{inserted_at: ...}` converted to the default timezone), with an optional explicit "date" arg override for manual runs.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 A retried job sends the email for the day it was enqueued, not the day it retried (test by constructing a job with an inserted_at from the previous day)
- [ ] #2 An explicit date arg overrides the derived date for manual runs
- [ ] #3 Timezone handling uses MusicLibrary.default_timezone() so the date matches the 7 AM Europe/London cron intent
- [ ] #4 Existing email content tests pass unchanged

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. In perform/1, accept the full %Oban.Job{} and derive the target date: `args["date"]` (Date.from_iso8601!) if present, else job.inserted_at (UTC) shifted to MusicLibrary.default_timezone() and truncated to Date.
2. Keep the cron entry unchanged (no args) — inserted_at at 07:00 Europe/London always lands on the correct local date.
3. Tests via Oban.Testing.perform_job/3 (or constructing the job struct): (a) inserted_at from yesterday → email is for yesterday's date; (b) explicit date arg wins; (c) existing content assertions (Swoosh.TestAssertions) pass.
4. Run the worker/email tests, then precommit.

<!-- SECTION:PLAN:END -->
