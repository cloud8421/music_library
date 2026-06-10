---
id: ML-212
title: Move Duration and RecordsOnThisDayEmail out of the web layer
status: To Do
assignee: []
created_date: "2026-06-10 10:38"
updated_date: "2026-06-10 10:55"
labels:
  - architecture
  - refactor
dependencies: []
references:
  - lib/music_library/records/tracklist_pdf.ex
  - lib/music_library/worker/send_records_on_this_day_email.ex
  - lib/music_library_web/records_on_this_day_email.ex
  - lib/music_library_web/duration.ex
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: medium
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

The only two domain→web dependencies in the codebase:

- `MusicLibrary.Records.TracklistPdf` (lib/music_library/records/tracklist_pdf.ex:7) aliases `MusicLibraryWeb.Duration` — a pure milliseconds-to-human-readable formatting utility.
- `MusicLibrary.Worker.SendRecordsOnThisDayEmail` (lib/music_library/worker/send_records_on_this_day_email.ex:4) aliases `MusicLibraryWeb.RecordsOnThisDayEmail` — the Swoosh email builder.

The dependency direction should be web→domain only. `Duration` is a trivial move. The email builder needs care: it embeds public asset URLs for cover images, so the move must not reintroduce a web dependency — URLs should be built from endpoint/application config rather than web-layer helpers, or the URL-building part stays parameterised. Decide the precise approach during implementation and keep the boundary clean.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 No module under lib/music_library/ references MusicLibraryWeb.\* (verified via grep or mix xref)
- [ ] #2 Duration lives in the MusicLibrary namespace; all call sites (including web ones) updated
- [ ] #3 RecordsOnThisDayEmail is callable from the worker without a domain→web alias and emails render identical output (asset URLs, anniversary styling)
- [ ] #4 Existing Duration and email tests are moved/updated to the new module locations and pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Move lib/music_library_web/duration.ex → lib/music_library/duration.ex; rename module to MusicLibrary.Duration; update aliases in TracklistPdf and web call sites (components/release.ex); move its test file accordingly.
2. Read lib/music_library_web/records_on_this_day_email.ex and list its web dependencies (asset URL building, endpoint/url usage, components).
3. Choose the URL strategy that keeps the domain web-free: build public asset URLs from application config (the public asset route shape is stable and already consumed by external clients/Presto) rather than verified routes. Document the choice in the moduledoc.
4. Move the module to lib/music_library/records_on_this_day_email.ex (MusicLibrary namespace, near MusicLibrary.Mailer); update the worker alias and the MaintenanceLive call site.
5. Move/adjust email tests; assert rendered HTML still contains correct cover URLs and anniversary styling (Swoosh.TestAssertions).
6. Verify boundary: `grep -r "MusicLibraryWeb" lib/music_library/` returns nothing; update docs/architecture.md module tables; run full precommit.
<!-- SECTION:PLAN:END -->
