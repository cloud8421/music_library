---
id: ML-154
title: >-
  Replace raise with Logger.warning in Repo.extension_path for unsupported
  platforms
status: To Do
assignee: []
created_date: '2026-04-30 10:48'
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
`MusicLibrary.Repo.extension_path/1` (`lib/music_library/repo.ex`) derives the platform from `:erlang.system_info(:system_architecture)` and raises `"Unsupported OS or platform"` if the combination isn't recognised.

This is called at startup in `config/runtime.exs` to load SQLite extensions (`unicode`, `vec0`). If deployed on an unexpected architecture, the app crashes before serving any traffic.

Change the function to:
1. Log a warning with the detected OS/arch details
2. Return `nil` (or an `{:error, reason}` tuple)
3. Update `config/runtime.exs` and any other callers to handle the nil/error case gracefully — skipping extension loading but allowing the app to start

Features that depend on the extensions (FTS5 unicode support, vector similarity search) will degrade but the app remains available.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `Repo.extension_path/1` logs a warning and returns nil instead of raising for unsupported platforms
- [ ] #2 `config/runtime.exs` handles a nil return by skipping extension loading for that extension
- [ ] #3 App can start on an unsupported platform without crashing
- [ ] #4 Existing supported platforms (darwin-amd64, darwin-arm64, linux-amd64, linux-arm64) continue to load extensions correctly
<!-- AC:END -->
