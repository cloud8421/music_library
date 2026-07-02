---
id: ML-15
title: Sanitize Wikipedia bio_html in ArtistLive.Show
status: Done
assignee: []
created_date: "2026-04-20 08:50"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/168"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-16 · updated 2026-04-16 · closed 2026-04-16_

## Summary

`lib/music_library_web/live/artist_live/show.ex:298` renders Wikipedia-sourced HTML via `Phoenix.HTML.raw(@biography.bio_html)` without sanitization or a `# sobelow_skip` annotation — inconsistent with the rest of the codebase.

## Evidence

- `bio_html` is produced in `lib/music_library_web/live/artist_live/biography.ex:13` from `ArtistInfo.wikipedia_bio/1`, reading `wikipedia_data["intro_html"]`
- Populated verbatim from Wikipedia's REST API in `lib/wikipedia.ex:14-15` — no sanitization before storage or rendering.
- Every other `raw()` site in the codebase either routes through `Markdown.to_html/1` (MDEx + ammonia) or carries a justified `# sobelow_skip ["XSS.Raw"]` comment (7 such sites verified).
- `biography.ex:76` already sanitizes the Last.fm bio path via `Markdown.to_html/1` — only the Wikipedia path is inconsistent.

## Risk

Low under the single-user threat model (Wikipedia's REST API returns sanitized HTML). Worth fixing for consistency so future reviewers don't have to re-derive the trust decision.

## Fix

Either:

1. Pipe `bio_html` through `MDEx.safe_html/2` with `MDEx.Document.default_sanitize_options()` (strongest), or
2. Add `# sobelow_skip ["XSS.Raw"]` at `show.ex:298` with a comment explaining Wikipedia is a trusted third-party HTML source (consistent with the other 7 annotation sites).

## Acceptance Criteria

<!-- AC:BEGIN -->

- Either HTML sanitization applied, or annotation + justification added
- Sobelow scan stays clean at `--exit high`

<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Either HTML sanitization applied, or annotation + justification added
- [ ] #2 Sobelow scan stays clean at `--exit high`

<!-- AC:END -->
