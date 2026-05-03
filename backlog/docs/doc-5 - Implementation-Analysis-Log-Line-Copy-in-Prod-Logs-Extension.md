---
id: doc-5
title: 'Implementation Analysis: Log Line Copy in Prod-Logs Extension'
type: other
created_date: '2026-05-03 21:06'
---
# Implementation Analysis: Log Line Copy in Prod-Logs Extension

## Problem Summary

The `/prod-logs` extension (`.pi/extensions/prod-logs/index.ts`) displays log lines in a scrollable viewer but offers no way to copy lines. The user wants:

1. Copy a single line (cursor line) and exit
2. Select and copy multiple lines and exit
3. Copied lines in ascending (chronological) order

## Architecture Context

- **Current component**: `LogViewer` class — manages scroll offset, renders lines, handles keyboard input
- **Current UI return type**: `ctx.ui.custom<void>` — no value returned on close
- **Current key bindings**: Escape/q (close), r (refresh), Up/k Down/j (scroll), PgUp/PgDn (page), Home/End (jump)
- **Line ordering**: `logLines.reverse()` is called before display, so newest-first visually. Copied lines should be oldest-first (ascending).
- **No cursor concept exists** — only a scroll offset

---

## Route A: Cursor + Toggle Selection + setEditorText

### Concept
Add a visual cursor line. Enter to copy single line. Space to toggle line selection (multi-select mode). `y` to copy all selected lines and exit. After exit, call `ctx.ui.setEditorText()` with the copied text.

### Changes to LogViewer
1. Add `cursorIndex: number` (absolute line index into `this.lines`)
2. Add `selectedIndices: Set<number>` (absolute indices)
3. New key bindings:
   - `Enter` → copy cursor line, `done(line)` 
   - `Space` → toggle selection of cursor line
   - `y` → copy selected lines (or cursor line if none selected), `done(text)`
4. Render changes:
   - `> ` prefix on cursor line (styled accent color)
   - `● ` prefix on selected lines (styled success color)
   - Non-selected, non-cursor lines keep existing `   ` prefix
5. Help text update: add "y copy · Space select · Enter copy line"

### Return value handling
```typescript
const copiedText = await ctx.ui.custom<string | null>(...);
if (copiedText !== null) {
  ctx.ui.setEditorText(copiedText);
}
```

### Pros
- No external dependencies
- `setEditorText` is already available in pi's ExtensionAPI
- Aligns with the "paste" use case (text in editor = ready to send or copy)
- Simple, contained change to one file

### Cons
- Modifies editor content (replaces whatever the user had typed)
- Not a true "system clipboard" copy — the user can't paste outside pi without an extra step
- Toggle-based selection for multi-line is somewhat unusual UX (vs. range selection)

---

## Route B: Visual Mode (Vim-style) + setEditorText

### Concept
Vim-inspired visual mode: `v` enters linewise visual selection, `j`/`k` extend the range, `y` copies and exits. Enter still copies single line. Selection is always a contiguous range.

### Changes to LogViewer
1. Add `cursorIndex: number` (absolute)
2. Add `visualMode: boolean` + `visualAnchor: number` (start of visual selection)
3. New key bindings:
   - `Enter` → copy cursor line, `done(line)`
   - `v` → enter visual mode (set anchor to cursor)
   - In visual mode: `j`/`k` extend selection range
   - `y` (in visual mode) → copy range [min(anchor,cursor)..max(anchor,cursor)], `done(text)`
   - `Escape` → exit visual mode
4. Render changes:
   - Selected range lines get `● ` prefix (styled)
   - Cursor line gets `> ` prefix
5. Help text: show visual mode help when active

### Pros
- Familiar UX for vim users
- Contiguous range selection is intuitive
- Same `setEditorText` approach — no external deps

### Cons
- Slightly more complex state machine (normal mode vs. visual mode)
- Doesn't allow non-contiguous selection (but the user said "contiguous")
- Still modifies editor content

---

## Route C: System Clipboard + Either Selection Model

### Concept
Either selection model (A or B), but instead of `setEditorText`, write to the system clipboard. Requires a package like `clipboardy`.

### Additional Changes
- Add `clipboardy` dependency (or use `node:child_process` with `pbcopy`/`xclip`)
- On copy: `clipboardy.writeSync(text)` or similar
- No need to change return type — can stay `void` since we don't pass text back

### Pros
- True "copy" behavior — paste anywhere
- Doesn't touch editor content
- Works across applications

### Cons
- External dependency (`clipboardy` — native module, may have install issues)
- Platform-specific behavior (macOS `pbcopy`, Linux `xclip`/`wl-copy`, Windows)
- pi extensions run in the pi process; clipboard access may have security implications
- May not work in headless/server environments where pi runs

---

## Recommendation: Route B (Visual Mode + setEditorText)

**Rationale:**
1. **No external dependencies** — `setEditorText` is already available
2. **Familiar UX** — vim-style visual mode is intuitive for developers
3. **Contiguous selection** — matches the user's "contiguous lines" description
4. **Simple implementation** — contained change to one file, ~100 lines of code
5. **Immediate value** — text in editor can be sent as a prompt or manually copied

**Why not clipboard (Route C):** The use case for `/prod-logs` is typically "I found an error line, I want to paste it into my next prompt to ask pi about it." `setEditorText` serves this perfectly. System clipboard adds complexity and platform fragility without proportional benefit for this specific use case.

**Why not toggle selection (Route A):** The user said "contiguous lines." Toggle-based selection allows non-contiguous selection, which they don't need. Visual mode is simpler to implement and more conventional.

---

## Outstanding Question for User

How should the copied text be placed in the editor?
- **Append** to current editor content (preserves what's there)
- **Replace** current editor content (clean slate)

My leaning: **Replace**, because the user's intent is to paste a log line as a new prompt.
