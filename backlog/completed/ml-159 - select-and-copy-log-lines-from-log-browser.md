---
id: ML-159
title: select and copy log lines from log browser
status: Done
assignee: []
created_date: "2026-05-03 21:05"
updated_date: "2026-05-03 21:34"
labels:
  - enhancement
  - pi-extension
  - prod-logs
dependencies: []
references:
  - .pi/extensions/prod-logs/index.ts
documentation:
  - doc-5 (Implementation Analysis)
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

When using the `/prod-logs` extension (`.pi/extensions/prod-logs/index.ts`), add the ability to select and copy log lines:

1. **Copy line under cursor** — The log browser currently has a scroll offset but no cursor concept. Add a visual cursor (highlighted line). On a keypress (e.g., Enter), copy that line, exit the log browser, and place the copied text where the user can paste it.

2. **Select and copy multiple contiguous lines** — Add a selection mechanism. The user starts a selection, toggles lines on/off, then completes the selection. Copied lines should be in ascending order (oldest first — reversed compared to the visual display which shows newest first). Exit the log browser afterward so the copied lines can be pasted.

The log browser currently uses `ctx.ui.custom<void>`. To return copied text, the return type should change to `string | null` (null = cancelled/closed without copy). After the custom UI resolves, the copied text should be placed somewhere the user can immediately use (e.g., set in the editor, or copied to system clipboard).

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Cursor line is visually highlighted with accent color and `> ` prefix
- [x] #2 `v` enters visual mode; highlighted range extends as cursor moves
- [x] #3 `Escape` exits visual mode and clears selection
- [x] #4 `Enter` in normal mode copies the cursor line to editor and closes log browser
- [x] #5 `y` in visual mode copies the selected range (oldest-first order) to editor and closes log browser
- [x] #6 Copied text appears in the editor (via setEditorText) after log browser closes
- [x] #7 Pressing Escape (without copying) closes the log browser without changing editor content
- [x] #8 All existing key bindings (scroll, page, refresh, jump) continue to work in both normal and visual modes
- [x] #9 Help text updates to show visual mode key bindings when visual mode is active
- [x] #10 Empty or single-line log responses handle gracefully (no crash, sensible behavior)

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Implementation Plan: Vim-style Visual Mode + setEditorText

### 1. Add cursor state to LogViewer

Add `cursorIndex` (absolute index into `this.lines`) and initialize to `0`. The cursor tracks which line is highlighted.

**Navigation model (vim-style):** All movement keys (`j`, `k`, `PgUp`, `PgDn`, `Home`, `End`, `g`, `G`) move `cursorIndex`. The `scrollOffset` auto-adjusts via a `clampViewport()` helper to keep the cursor within the visible range `[scrollOffset, scrollOffset + visibleHeight)`. This unifies normal and visual mode key handling — in visual mode, the same keys extend the selection by moving `cursorIndex` while `visualAnchor` stays fixed.

Add a `clampViewport()` private method:

- If `cursorIndex < scrollOffset`, set `scrollOffset = cursorIndex`
- If `cursorIndex >= scrollOffset + visibleHeight`, set `scrollOffset = cursorIndex - visibleHeight + 1`
- Call `clampViewport()` after every cursor movement and after `updateLines()`

When lines are refreshed via `updateLines()`, reset `cursorIndex = 0`, `visualMode = false`, and `visualAnchor = 0`, then call `clampViewport()` and `invalidate()`.

**Verification**: After opening log browser, the first visible line should be highlighted with `> ` prefix and accent color. Press `j` — cursor moves to line 2, viewport unchanged. Press `G` — cursor jumps to last line, viewport shifts to show it. Press `g` twice — cursor jumps to line 1, viewport shifts back to top. Refresh logs — cursor resets to 0, visual mode cleared.

### 2. Add visual mode state to LogViewer

Add `visualMode: boolean` and `visualAnchor: number`. `v` key enters visual mode, setting `visualAnchor = cursorIndex`. `Escape` exits visual mode (clears `visualMode` and resets `visualAnchor`).

In visual mode, all movement keys (`j`, `k`, `PgUp`, `PgDn`, `Home`, `End`, `g`, `G`) extend the selection range by moving `cursorIndex` while `visualAnchor` stays fixed. The selected range is `[min(anchor, cursor), max(anchor, cursor)]`.

**Verification**: Press `v` — visual mode indicator appears in help bar. Selection range highlights between anchor and cursor. Move with `j`/`k` — selection expands/shrinks. Press Escape — visual mode clears, selection disappears, cursor stays at current position.

### 3. Update render to show cursor highlight and selection range

- Cursor line: `> ` prefix with `theme.fg("accent", ...)`
- Selected lines (in range): `● ` prefix with `theme.fg("success", ...)`
- Lines that are both cursor AND in selection: `> ` prefix takes priority (cursor indicator)
- Non-cursor, non-selected: keep existing `NNN │` prefix

The line number column must shift right by 2 characters to accommodate the new prefix: `  NNN │ > text` instead of ` NNN │ text`.

**Verification**: Visual inspection. Toggle visual mode, move cursor — see correct highlights. Exit visual mode — highlights disappear.

### 4. Add copy key bindings

- `Enter` (normal mode): Copy cursor line → `done(line)` (single line as string)
- `y` (visual mode): Copy range `[min(anchor, cursor)..max(anchor, cursor)]` joined with `\n` → `done(text)`
- Copied text must be in **ascending order** (oldest first). Since `this.lines` is already reversed before display (index 0 = newest, last index = oldest), use `this.lines.slice(start, end + 1).reverse().join("\n")` to get oldest-first ordering.

**Verification**: Copy a range of lines. The resulting text should have oldest timestamp first, newest last. Use manual testing with logs that have visible timestamps.

### 5. Change ctx.ui.custom return type from void to string | null

```typescript
const copiedText = await ctx.ui.custom<string | null>(
  (tui, theme, _kb, done) => {
    viewer.onCopy = (text: string) => done(text);
    viewer.onClose = () => done(null);
    // ...
  },
);

if (copiedText !== null) {
  ctx.ui.setEditorText(copiedText);
}
```

**Verification**: Copy a line → editor shows the copied text. Press Escape → editor remains unchanged (empty).

### 6. Update help text

Normal mode: `↑↓/jk scroll · PgUp/PgDn page · Home/End jump · v visual · Enter copy line · r refresh · Esc close`

Visual mode: `VISUAL: j/k extend · y copy · Esc cancel · Enter copy line`

**Verification**: Visual inspection of the help bar in both modes.

### 7. Handle edge cases

- **Empty log**: No copy operations allowed (`cursorIndex = -1` when `lines.length === 0`). Show "(no logs)".
- **Single line logs**: Visual mode works (range = just that one line). Enter copies it.
- **Cursor clamping on update**: After refresh, `updateLines()` resets `cursorIndex = 0`, `visualMode = false`, `visualAnchor = 0`, then calls `clampViewport()`.
- **Visual mode across refresh**: `updateLines()` exits visual mode (lines change, anchor becomes stale).
- **Cursor out of bounds after delete-like operations**: N/A — log lines are append-only; `updateLines()` always handles the reset.

**Verification**: Test with empty API response, single-line response, and normal multi-line response. Refresh during visual mode — confirm mode exits.

## Architecture Impact Analysis

This is a **single-file, frontend-only change** to `.pi/extensions/prod-logs/index.ts`. No Elixir code, database schemas, contexts, PubSub topics, routes, or external API contracts are affected.

### Touchpoints

| Component                  | Impact                                                                                                                                                                                                                                                  |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LogViewer` class          | **Modified** — adds `cursorIndex`, `visualMode`, `visualAnchor`, `onCopy` callback, `clampViewport()` private method. Movement keys refactored to move `cursorIndex` with viewport auto-clamping. `handleInput` routing restructured for mode awareness |
| `LogViewer.render()`       | **Modified** — adds cursor prefix (`> `) and selection prefix (`● `). Line number column padding widened by 2 chars                                                                                                                                     |
| `LogViewer.updateLines()`  | **Modified** — resets `cursorIndex = 0`, `visualMode = false`, `visualAnchor = 0`, calls `clampViewport()`                                                                                                                                              |
| Extension handler function | **Modified** — `ctx.ui.custom<void>` → `ctx.ui.custom<string \| null>`. Adds `onCopy` handler. Adds `ctx.ui.setEditorText()` on copy                                                                                                                    |
| Help text strings          | **Modified** — split into normal-mode and visual-mode variants                                                                                                                                                                                          |
| `fetchLogs` / Coolify API  | **No change** — data fetching unchanged                                                                                                                                                                                                                 |

### Deprecation/Migration

None. Old behavior (scroll + refresh + close) is preserved and extended, not replaced.

---

## Performance Profile

- **Runtime complexity**: O(visibleHeight) per render — no change from current. Cursor and selection checks are O(1) per rendered line
- **Memory**: O(1) for cursor/anchor/visualMode fields; selection range is computed from two integers (no set storage)
- **Database queries**: None (client-side only)
- **N+1 risk**: None
- **Latency**: Zero latency added — all state changes are synchronous integer operations

---

## Benchmarking Requirements

**None required.** This is a purely interactive UI change with no database, network, or computational hot paths. The render path is identical to the existing code except for two integer comparisons per rendered line.

---

## Cost Profile

**No paid resources consumed.** The change does not add API calls, storage, compute, or third-party service usage beyond what already exists.

---

## Production Infrastructure Steps

**None.** No environment variables, service provisioning, database migrations, DNS changes, or firewall rules are needed. The extension is deployed as part of the pi extensions directory alongside the project.

---

## Documentation Updates

| File                                | Change Needed                                                                                                                      |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `docs/architecture.md`              | **No change** — this is a pi extension, not part of the Elixir application architecture                                            |
| `docs/project-conventions.md`       | **No change** — TypeScript conventions are pi's domain, not the project's                                                          |
| `docs/production-infrastructure.md` | **No change** — no infra changes                                                                                                   |
| `docs/available-tasks.md`           | **No change** — no new mise tasks                                                                                                  |
| `.pi/extensions/prod-logs/index.ts` | **Inline comments** — add JSDoc on new fields (`cursorIndex`, `visualMode`, `visualAnchor`, `onCopy`) and new key binding branches |

<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Added vim-style cursor navigation and visual mode to the prod-logs pi extension:

- **Cursor**: `cursorIndex` tracks the highlighted line; all movement keys (j/k/PgUp/PgDn/Home/End/g/G) move the cursor with viewport auto-clamping via `clampViewport()`.
- **Visual mode**: `v` enters range selection; movement keys extend the highlighted range (success color, `● ` prefix). Escape exits visual mode.
- **Copy**: Enter copies the cursor line to the editor. `y` in visual mode copies the selected range in oldest-first order.
- **Return type**: `ctx.ui.custom<void>` changed to `ctx.ui.custom<string | null>`; copied text placed via `ctx.ui.setEditorText()`.
- **Edge cases**: Empty logs set cursorIndex to -1; visual mode guarded against empty state; `updateLines()` resets all navigation state on refresh.
- **Help text**: Mode-aware — normal mode shows full key bindings, visual mode shows selection-specific keys.

Single-file change to `.pi/extensions/prod-logs/index.ts`. No Elixir code, database, or infrastructure changes. All 890 tests pass.

<!-- SECTION:FINAL_SUMMARY:END -->
