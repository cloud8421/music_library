---
id: ML-154
title: Add early platform detection in runtime.exs for SQLite extensions
status: Done
assignee: []
created_date: '2026-04-30 10:48'
updated_date: '2026-04-30 12:37'
labels:
  - robustness
  - sqlite
dependencies: []
references:
  - lib/music_library/repo.ex
  - config/runtime.exs
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`MusicLibrary.Repo.extension_path/1` raises `"Unsupported OS or platform"` when run on an unrecognised OS/architecture combination. This is called at startup via `config/runtime.exs` to resolve paths for `unicode` and `vec0` SQLite extensions.

Instead of silently degrading (which would cause confusing downstream failures), add early detection:

1. Add `MusicLibrary.Repo.supported_platform?/0` that returns a boolean
2. In `config/runtime.exs`, check this BEFORE the `load_extensions` config block
3. If unsupported, raise with a helpful message listing supported platforms and the detected OS/arch

The existing `raise` in `extension_path/1` stays as a defensive fallback (should not be reached if runtime.exs catches it first).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 #1 `Repo.supported_platform?/0` returns true/false based on OS/arch
- [x] #2 #2 `config/runtime.exs` checks `supported_platform?/0` before loading extensions and raises with a helpful message on unsupported platforms
- [x] #3 #3 Existing supported platforms (darwin-amd64, darwin-arm64, linux-amd64, linux-arm64) continue to load extensions correctly
- [x] #4 #4 `extension_path/1` raise stays as a defensive fallback
<!-- AC:END -->
