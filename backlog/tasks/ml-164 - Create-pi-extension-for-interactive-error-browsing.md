---
id: ML-164
title: Create pi extension for interactive error browsing
status: To Do
assignee: []
created_date: '2026-05-04 08:08'
updated_date: '2026-05-04 08:19'
labels:
  - pi
dependencies: []
parent_task_id: DRAFT-1
priority: medium
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Build a pi extension that provides an interactive TUI for browsing production errors, using the `fetch_production_errors` and `fetch_production_error` tools from the parent task.

This extension gives the user (and LLM) a browseable interface for production errors, accessible via a slash command like `/prod-errors`.

### Extension features

1. **`/prod-errors` command** — Opens an interactive TUI using `ctx.ui.custom()`:
   - Lists recent errors (unresolved first, then by last_occurrence_at desc)
   - Shows key metadata: reason (truncated), kind, source location, occurrence count, last seen, status badge, muted indicator
   - Keyboard navigation: up/down to select, Enter to view details, Escape to close
   - Filter toggle: show/hide resolved, show/hide muted (keyboard shortcuts)
   - Pagination: load more errors as user scrolls

2. **Error detail view** (Enter on an error):
   - Full reason text
   - Source location with link-like formatting
   - Status, muted, fingerprint
   - Timeline of occurrences with timestamps
   - Stacktrace display (collapsible per occurrence)
   - Context display (request path, LiveView, etc.)
   - Breadcrumbs if present

3. **UI patterns** (consistent with existing `/prod-logs` extension):
   - Uses `pi.exec("curl", ...)` to call the API
   - Reads credentials from `resolveVar()` (same pattern as prod-logs)
   - Keyboard shortcuts displayed as hints
   - Theme-aware rendering via `ctx.ui.theme`

### TUI component design

```
╔══════════════════════════════════════════════════╗
║ Production Errors                    [12 errors] ║
╠══════════════════════════════════════════════════╣
║ ▶ [UNRESOLVED] FunctionClauseError               ║
║   MusicLibrary.Foo.bar/2  lib/foo.ex:42          ║
║   23 occurrences · last seen 2h ago              ║
║ ──────────────────────────────────────────────── ║
║   [RESOLVED]   MatchError                          ║
║   MusicLibrary.Baz.qux/1  lib/baz.ex:15          ║
║   5 occurrences · last seen 3d ago               ║
║ ──────────────────────────────────────────────── ║
║   [MUTED]      KeyError (key :foo not found)     ║
║   MusicLibrary.Other.func/3  lib/other.ex:99     ║
║   1 occurrence · last seen 7d ago                ║
║ ──────────────────────────────────────────────── ║
║                                                  ║
║  ↑↓ navigate  ↵ details  r toggle resolved      ║
║  m toggle muted  q quit                          ║
╚══════════════════════════════════════════════════╝
```

### File location

`.pi/extensions/prod-errors/index.ts` (new extension, separate from `prod-logs`)

The prod-logs extension already provides the `resolveVar` pattern and `fetchLogs` function. This extension follows the same conventions but for error_tracker data.
<!-- SECTION:DESCRIPTION:END -->
