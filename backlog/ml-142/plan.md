# Improve scrobble UI in the Release component

## Context

The Release sheet's scrobble controls have three concrete friction points, confirmed on review:

1. **Navigation.** On a multi-medium release, the only way to scrobble a cross-medium selection is the top-level button — users have to scroll all the way back up after picking tracks on disc 3.
2. **No picker for `finished_at`.** The timestamp is always `DateTime.utc_now()`; there is no UI to backfill a listening session. `ScrobbleActivity.scrobble_release/3`, `scrobble_medium/4`, and `scrobble_tracks/4` already accept a `DateTime`, so this is purely a UI gap.
3. **Disabled buttons aren't visually distinct.** All scrobble buttons use `variant="soft"` with only `opacity-70` for disabled — hard to tell state apart. The per-medium button is *always* disabled when any track is selected anywhere, which is surprising.

A fourth issue surfaced in review: the **print** icon is omnipresent (release + every medium) but rarely used, taking up valuable primary-action space.

The accepted UX direction (Option A, see `backlog/ml-142/mockups.html`) is a three-tier action hierarchy:

- **Header → whole release** (primary action, solid button)
- **Per-medium → that disc** (soft shortcut, always enabled)
- **Sticky footer → selected tracks** (appears only when tracks are ticked)

A single "Finished at" picker in the header drives all three, defaulting to "Now" (nil) until changed. Print moves into a `⋯` overflow menu on both the release header and each medium header.

## Scope

### In scope

- `lib/music_library_web/components/release.ex` — the LiveComponent and the shared `.medium/1` / `.track_list/1` function components it exports.
- `lib/music_library_web/live/scrobble_live/show.ex` — the standalone scrobble page, which imports `.medium/1`; behaviour must stay coherent with the new component contract (the selection-blocks-medium-scrobble bug is removed there too).
- New user-facing strings wrapped in `gettext`; `.pot`/`.po` regenerated.
- Tests: new coverage for the Release LiveComponent's event handlers and the sticky-bar rendering, plus an updated handler test for `ScrobbleLive.Show` confirming medium-scrobble now works with tracks selected.

### Out of scope

- `MusicLibrary.ScrobbleActivity` — no context changes. All three functions already take a `DateTime`.
- A full sticky-bar + picker port to `ScrobbleLive.Show`. That page uses its own layout (not the sheet) and can be iterated on separately once the LiveComponent pattern is settled.
- Changes to `ScrobbleComponents` function module — it isn't used by the Release sheet.
- No database, migration, Oban, or JS-hook work.

## Implementation

### 1. Header restructure (`release.ex:89-164`)

Replace the current flex row ("Tracks" label + print + scrobble + auth) with a two-block structure that reflows on narrow viewports:

```
<div class="flex items-start justify-between gap-3">
  <div>
    {release_title}
    {release_subtitle}  (# of mediums · year)
  </div>
  <div class="flex flex-wrap items-center justify-end gap-2">
    <.date_time_picker_pill ... />
    <.button variant="solid" phx-click="scrobble_release" ...>
      ▶ Scrobble release
    </.button>
    <.dropdown>
      <.button variant="outline" size="sm">⋯</.button>
      <:item><.dropdown_link phx-click="print_tracklist">Print tracklist</.dropdown_link></:item>
      <:item :if={!@can_scrobble?}><.dropdown_link href={LastFm.auth_url()}>Connect Last.fm</.dropdown_link></:item>
    </.dropdown>
  </div>
</div>
```

- Drop the existing single-medium "Tracks" master checkbox (it duplicates the medium-level checkbox that's always rendered now).
- Mobile (`< sm:`): the wrapping grid collapses so the title row holds title + `⋯`, and the second row holds the picker (flex-1) + "Scrobble release" (hug contents).
- The "Scrobble release" button is `variant="solid"` (Fluxon's primary colour) — this is the contrast fix mandated by AC#2 on the primary flow.

### 2. `.medium/1` function component (`release.ex:221-283`)

Three changes:

- **Remove the selection-based disable** on the scrobble button (`release.ex:260`): `disabled={@already_scrobbled || MapSet.size(@selected_tracks) > 0}` → `disabled={@already_scrobbled}`. This is the AC#3 unblock.
- **Add a label** to the scrobble button ("Scrobble disc" / "Scrobble side" via `medium_scrobble_label/1`, which already exists). Keep `variant="soft"`, `color="primary"` — visually secondary to the release button but with colour anchoring it as "this is scrobbling".
- **Replace the separate print button** with a `.dropdown` trigger identical in shape to the header's `⋯` menu; print lives inside. Keeps one row per medium without losing the feature.

The function-component signature stays backward-compatible: the existing `myself` / `already_scrobbled` / `selected_tracks` attrs are retained. `ScrobbleLive.Show` renders this component unchanged, so the fix propagates there automatically.

### 3. Sticky selection bar (new, inside `release.ex` render)

Rendered at the bottom of the sheet body, conditional on `MapSet.size(@selected_tracks) > 0`:

```
<div class="sticky bottom-0 bg-white dark:bg-zinc-900 border-t border-zinc-200 dark:border-zinc-700
            shadow-[0_-4px_14px_rgba(0,0,0,0.06)] px-4 py-2 flex items-center justify-between gap-3">
  <div class="flex flex-col leading-tight">
    <span class="text-sm font-semibold">{count} tracks selected</span>
    <span class="text-xs text-zinc-500 dark:text-zinc-400">across {medium_count} discs · {duration}</span>
  </div>
  <.button variant="solid" phx-click="scrobble_selected_tracks" ...>
    ▶ Scrobble selected
  </.button>
</div>
```

Helpers (private, in `release.ex`):

- `selected_tracks_summary/2` — takes `%{release, tracks: [...]}`and `MapSet` → returns `{count, medium_count, total_duration_ms}`. Reuses the existing `Release.tracks/1` flattening.
- Duration formatted via the existing `MusicLibraryWeb.Duration.format_milliseconds/1`.

The sticky element sits inside the scrollable sheet body so it pins to the bottom of the visible area, not the viewport.

### 4. `finished_at` wiring

Add a `finished_at` field to the form data in `release.ex`:

- `mount/1`: initial form is `to_form(%{"selected_tracks" => [], "toggle_medium" => [], "finished_at" => nil})`.
- `handle_event("validate", params, socket)` (already exists, lines 408-423): extend `apply_form_params/3` to parse `params["release"]["finished_at"]` into `DateTime.t() | nil` (ISO8601 via `DateTime.from_iso8601/1`, nil on blank or parse failure) and assign under `:finished_at`.
- The three scrobble handlers (`scrobble_release`, `scrobble_medium`, `scrobble_selected_tracks`) resolve the timestamp at call time:

  ```elixir
  finished_at = socket.assigns.finished_at || DateTime.utc_now()
  ```

  Then pass it as the existing `:finished_at` argument to `ScrobbleActivity.*`.

Rendering the control: use Fluxon's `<.date_time_picker field={@form[:finished_at]} label={gettext("Finished at")} display_format="%b %-d, %H:%M" />`, already used in `record_form.ex:57-63`. When the field is nil, the picker shows its placeholder; rendering "Now" as the displayed value when `@finished_at` is nil is done via a small wrapper (`finished_at_display/1`) rather than the picker internals, so the behaviour is obvious in the template.

A **Reset to now** affordance: if Fluxon's picker exposes a clear action (likely via its popover footer — confirm in browser), use it; otherwise mimic pattern used in `MusicLibraryWeb.StatsLive.Index` for the `on_this_day/1` component, which adds a button next to the picker that pushes a `"clear_finished_at"` event which `assign(:finished_at, nil)` and updates the form.

### 5. Event handlers — summary of changes

| Event | Before | After |
|---|---|---|
| `scrobble_release` | `DateTime.utc_now()` hardcoded | `@finished_at || DateTime.utc_now()` |
| `scrobble_medium` | disabled when selection present; always `utc_now()` | always enabled; uses `@finished_at || utc_now()` |
| `scrobble_selected_tracks` | `DateTime.utc_now()` hardcoded | `@finished_at || DateTime.utc_now()` |
| `clear_finished_at` | — | new; resets form field + assign |
| `validate` | parses `selected_tracks` + `toggle_medium` | also parses `finished_at` |

The `already_scrobbled` 3-second lockout stays as-is.

### 6. `ScrobbleLive.Show` — minimal updates

`lib/music_library_web/live/scrobble_live/show.ex`:

- The imported `.medium/1` renders the new "Scrobble disc" label + `⋯` dropdown; since this page has its own print handlers already (`"print_medium_tracklist"`), wire the dropdown `phx-click` to those.
- `handle_event("scrobble_medium", ...)` loses no behaviour — it already doesn't gate on selection (the guard was only in the component). Verify and add a regression test.
- No picker, no sticky bar added in this pass — those stay scoped to the LiveComponent. The page continues to use `DateTime.utc_now()`.

### 7. Gettext

New strings (all under existing `MusicLibraryWeb.Gettext`):

- `"Finished at"`, `"Now"`, `"Reset to now"`
- `"Scrobble release"`, `"Scrobble disc"`, `"Scrobble selected"`
- ngettext: `"%{count} track selected"` / `"%{count} tracks selected"`
- `"across %{count} discs"` — may already exist; reuse if so
- `"More actions"` — for the `⋯` button's screen-reader label

Run `mix gettext.extract --merge` after implementation.

## Files touched

- `lib/music_library_web/components/release.ex` — the primary change (render, handlers, helpers).
- `lib/music_library_web/live/scrobble_live/show.ex` — dropdown wiring for print; regression test for medium-scrobble-with-selection.
- `test/music_library_web/components/release_test.exs` — **new file**. Covers:
  - Picker: default "Now" render; setting a value persists; `clear_finished_at` resets to nil.
  - Sticky bar: hidden when no selection; visible with accurate count/duration when tracks ticked.
  - `scrobble_release`, `scrobble_medium`, `scrobble_selected_tracks` each respect the picker value (assert the arg passed to `ScrobbleActivity` via a `Mox`-style expect or by stubbing `LastFm` via `Req.Test` and asserting on the scrobbled timestamps).
  - Medium button is clickable (not disabled) when cross-medium selection is present.
- `test/music_library_web/live/scrobble_live/show_test.exs` — update / add regression asserting `scrobble_medium` works with selection.
- `priv/gettext/*.pot`, `priv/gettext/*/LC_MESSAGES/*.po` — regenerated by `mix gettext.extract --merge`.

No other files expected. Confirmed: `scrobble_components.ex` is not used by the Release sheet.

## Verification

1. `mise run dev:precommit` — format, Credo, Sobelow, ExSlop, gettext check, tests. Must pass.
2. Manual browser checks with the dev server running. Required for UI work per project convention:
   - **Desktop (~1200px, light + dark mode):** open a 2-CD release in Collection. Header shows picker + "Scrobble release" + `⋯`. Per-medium rows show "Scrobble disc" + `⋯`. Print lives only inside `⋯` menus. Contrast: solid release button is obviously different from disabled state (3-second lockout after scrobble).
   - **Mobile (360px):** header stacks — title+⋯ row, then picker+"Release" button row. Per-medium button collapses to icon-only. Sticky bar still readable (no horizontal overflow).
   - **Cross-medium scrobble:** tick one track on disc 1, one on disc 2 → sticky bar appears "2 tracks selected across 2 discs · 10:45" → click "Scrobble selected" → toast, sticky bar disappears.
   - **Per-medium scrobble with selection present:** tick a track on disc 1 → click "Scrobble disc" on disc 2 → disc 2 scrobbles (unaffected by selection). Verify via `/dev/oban` or Last.fm.
   - **Custom finished_at:** pick a time yesterday → click "Scrobble release" → verify the scrobbled timestamp in Last.fm matches the picked time (minus release duration for started_at).
   - **Reset to now:** set a custom time → click reset → picker shows "Now" → scrobble uses `utc_now()`.
3. `mix test test/music_library_web/components/release_test.exs` — new LiveComponent tests pass.
4. `mix test test/music_library_web/live/scrobble_live/show_test.exs` — regression test for medium-scrobble-with-selection passes.
5. `grep -n "MapSet.size(@selected_tracks) > 0" lib/music_library_web/components/release.ex` — should return nothing except the sticky-bar visibility guard (which is intended).

## Open items deferred to implementation

- Exact Tailwind classes for the sticky bar shadow/padding — start with the mockup values, tune in the browser.
- Pluralisation of "across N discs" — if the release is single-medium, the subtitle should drop the "across 1 discs" clause and show just the duration. Small conditional in `selected_tracks_summary/2`.
- Whether to show the picker on releases where `@can_scrobble?` is false. Recommend hiding it in that case (no point picking a time if you can't submit) — to confirm in review.
