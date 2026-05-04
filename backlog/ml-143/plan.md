# Cart-style multi-record import

## Context

Today the "Add Record" modal (`lib/music_library_web/components/add_record.ex`) imports one record at a time: click the `+` icon on a MusicBrainz result, pick a format from the dropdown, the LiveView calls `Records.import_from_musicbrainz_release_group/2` synchronously, toasts, and `push_navigate`s to the new record. Importing several records in a sitting means repeating that loop.

This change turns the modal into a shopping-cart flow. The user stages multiple `{release_group, format}` items in an ephemeral cart, then hits **Import N records** once. Small batches run sync in the modal (spinner in the button); larger batches enqueue Oban jobs and close the modal with a "Importing N in background" toast — mirroring the existing barcode-scan threshold logic.

Goal: reduce repetitive clicking when adding multiple records from the same search session, reusing the project's existing async-import and LiveComponent patterns.

## Scope

UI direction (already agreed):

- Mockup **B** (bottom tray) on small viewports (default / `sm:`).
- Mockup **A** (side-by-side: search left, cart right) on `md:` and up — the import modal widens to fit.
- Empty cart state shown in-place (not hidden).
- Format picker keeps the existing `dropdown` + `dropdown_link` UI; the click adds to the cart rather than importing.

Batch size behaviour (mirrors `BarcodeScan`):

- **1 item**: sync via `start_async`. Spinner in the "Import 1 record" button; modal stays open during the call; on success parent does `push_navigate` to the new record + toast; on error the modal stays open and shows an error toast.
- **2+ items**: enqueue one `ImportFromMusicbrainzReleaseGroup` Oban job per cart item via `Oban.insert_all/1`; parent toasts "Importing N records in the background..." and `push_patch`es back to the base index (modal closes).

Duplicate cart entries: deduped by `{release_group_id, format}`. Adding the same pair twice is a no-op; adding the same release group with a different format creates a second cart row (users can own multiple formats of a release — consistent with the existing "allow duplicate imports" stance).

Out of scope:

- Persisted cart (explicitly ephemeral).
- Stats page `handle_event("import", ...)` at `lib/music_library_web/live/stats_live/index.ex:113` — different flow (`import_from_musicbrainz_release`, singular), untouched.
- Barcode scanner flow — already batches; no change.

## Implementation

### 1. New Oban worker — `MusicLibrary.Worker.ImportFromMusicbrainzReleaseGroup`

New file: `lib/music_library/worker/import_from_musicbrainz_release_group.ex`.

- `use Oban.Worker, queue: :music_brainz, max_attempts: 3`
- Args: `%{"release_group_id" => string, "format" => string, "purchased_at" => iso8601_string}`
- `perform/1` parses the format (`String.to_existing_atom/1` after whitelisting against `Records.Record.formats()`), parses the datetime, and delegates to `Records.import_from_musicbrainz_release_group/2`.
- Returns `:ok` on success, `{:error, reason}` on failure (Oban retries).

Mirror the structure of `lib/music_library/worker/import_from_musicbrainz_release.ex` exactly.

### 2. `structured_modal` gains a width attr

`lib/music_library_web/components/core_components.ex:154-173`. Currently hardcodes `md:max-w-3xl`.

- Add `attr :width_class, :string, default: "md:max-w-3xl"`.
- Interpolate at the tail of the class string: `"mx-auto mt-8 max-w-sm sm:min-w-2xl #{@width_class}"`. Tailwind last-wins handles override.
- Name is `width_class` (not `max_width`) to make it clear the caller supplies a Tailwind utility and that it's appended, so they remember to include responsive prefixes.
- Backwards-compatible: the 13 existing callers keep today's width unchanged.

### 3. `AddRecord` LiveComponent — cart state and responsive layout

`lib/music_library_web/components/add_record.ex`.

#### Assigns (added to `mount/1`)

- `cart :: [%{cart_item_id, release_group_id, title, artists, release_date, thumb_url, format}]` — ordered list, newest first. `cart_item_id` via `System.unique_integer([:positive])`.
- `cart_pairs :: MapSet.t({binary, atom})` — set of `{release_group_id, format}` for O(1) "already in cart" and dedup checks.
- `cart_expanded? :: boolean` — mobile tray collapse; defaults to `true`. Always-expanded on `md:` via Tailwind `md:!block`.
- `importing? :: boolean` — single-item sync spinner flag.

#### Events (all `phx-target={@myself}`)

- `"add_to_cart"` — payload `%{"id" => rg_id, "format" => format_str, "title" => ..., "artists" => ..., "release_date" => ..., "thumb_url" => ...}`. Display fields come from `JS.push` values on the dropdown link so we don't need a parallel `release_groups_by_id` map. Validates `format_str` against `Records.Record.formats()`. If `{rg_id, format_atom}` already in `cart_pairs`, no-op.
- `"remove_from_cart"` — `%{"cart_item_id" => id}`. Updates `cart` + `cart_pairs`.
- `"change_format"` — `%{"cart_item_id" => id, "format" => format_str}`. Whitelists format. No-op if the new `{rg_id, format_atom}` would collide with another cart row.
- `"clear_cart"` — empties both assigns.
- `"toggle_cart"` — flips `cart_expanded?` (mobile only; no-op visually on `md:+`).
- `"import_cart"` — dispatches:
  - `[]`: silently ignored (button is disabled anyway).
  - `[single]`: `assign(:importing?, true)` + `start_async(:import_cart, fn -> Records.import_from_musicbrainz_release_group(rg_id, format: format, purchased_at: now) end)`.
  - `[_, _ | _]`: builds a list of `ImportFromMusicbrainzReleaseGroup.new/1` changesets, single `Oban.insert_all/1` call (atomic — no partial enqueue on failure), then `notify_parent({:imported_async, count})`.

#### `handle_async(:import_cart, ...)`

- `{:ok, {:ok, record}}` → `notify_parent({:imported_single, record})`. Parent handles navigation + toast + modal close; no local reset needed since the component is about to unmount.
- `{:ok, {:error, reason}}` → `put_toast!(:error, gettext("Error importing record") <> ": " <> ErrorMessages.friendly_message(reason))`, `assign(:importing?, false)`. Modal stays open so the user can adjust the cart.
- `{:exit, reason}` → `Logger.warning(inspect(reason))` + generic error toast, reset `importing?`.

#### `notify_parent/1`

Private helper: `defp notify_parent(msg), do: send(self(), {__MODULE__, msg})`. Matches the convention used in `record_form.ex:646`, `online_store_template_live/form.ex:140`, etc.

#### Render structure

Root becomes a responsive grid:

```
<div class="grid grid-cols-1 md:grid-cols-5">
  <section class="md:col-span-3 ...">   <!-- search + results (today's UI) -->
  <aside  class="md:col-span-2 border-t md:border-t-0 md:border-l ..."> <!-- cart -->
</div>
```

Results column keeps the existing search input + stream + `max-h-125 overflow-y-auto` + `phx-viewport-bottom` load-more. Each result row gets an "In cart" chip when `MapSet.member?(@cart_pairs, {rg_id, any_format})` — a cheap helper `in_cart?/2`. The `+ icon → dropdown` loop unchanged; only the `phx-click` target becomes `JS.push("add_to_cart", value: %{id:, format:, title:, artists:, release_date:, thumb_url:}, target: "##{@id}")` with `page_loading: false` removed (cart-add is instant).

Cart column:

- Header: cart count, "Clear all" link (both gettext'd), mobile chevron (`phx-click="toggle_cart"`) hidden on `md:+`.
- Body wrapped in `<div class={["md:!block", not @cart_expanded? and "hidden"]}>` so mobile collapse doesn't leak past `md:` (`md:!block` is the important-override).
  - Empty state when `@cart == []`: music icon + short gettext'd hint.
  - Otherwise the list: thumbnail, artists/title, per-row format `<select>` (posts `"change_format"`), "Remove" text button.
  - Scroll container `md:max-h-[calc(100vh-12rem)] overflow-y-auto` so a long cart doesn't push the footer off-screen.
- Footer: "Import N records" button (`phx-click="import_cart"`, `ngettext` for the label). Disabled when cart empty OR `@importing?`. Icon swap: `hero-arrow-path animate-spin` when `@importing?`, otherwise `hero-plus`. Button hidden when cart empty — empty-state has its own guidance.

Dropdown placement on `md:col-span-3` may need `placement="left-start"` at `md:` to avoid right-edge clipping in the narrower results column — verify in the browser and adjust if needed.

### 4. Parent LiveViews — wire the cart messages

`lib/music_library_web/live/collection_live/index.ex` and `lib/music_library_web/live/wishlist_live/index.ex`.

- Remove the `handle_event("import", ...)` clause and its call to `IndexActions.handle_import/3` (not dropping `IndexActions.handle_import/3` itself yet — see step 6).
- Add:

  ```elixir
  def handle_info({AddRecord, {:imported_single, record}}, socket),
    do: IndexActions.handle_cart_imported_single(socket, record)

  def handle_info({AddRecord, {:imported_async, count}}, socket),
    do: IndexActions.handle_cart_imported_async(socket, count)
  ```

- Update the `structured_modal` call for `live_action == :import` to pass `width_class="md:max-w-4xl lg:max-w-5xl"`. The other `structured_modal` calls (edit, barcode scan) keep the default width.
- Pass `on_close={nil}` (or a no-op) on the import modal while `@importing?`. Simplest: pass the close handler only when not importing — but `@importing?` is a component assign, not exposed to the parent. Alternative: the component's `toggle_cart` / close button is a no-op while importing; the outer Fluxon modal close still works. Accept this: if the user closes the modal mid-import, the `handle_async` callback lands on a detached component and is silently dropped by Phoenix — no user-visible bug. Add a short comment in the component pointing this out.

### 5. `IndexActions` — new shared helpers

`lib/music_library_web/live_helpers/index_actions.ex`.

- `handle_cart_imported_single(socket, record)`:

  ```elixir
  config = socket.assigns.index_config

  {:noreply,
   socket
   |> put_toast(:info, config.import_success_toast)
   |> push_navigate(to: config.record_path_fn.(record.id))}
  ```

  Reuses `config.import_success_toast` and `config.record_path_fn` that already exist.

- `handle_cart_imported_async(socket, count)`:

  ```elixir
  config = socket.assigns.index_config

  msg =
    ngettext(
      "Importing %{count} record in the background...",
      "Importing %{count} records in the background...",
      count,
      count: count
    )

  {:noreply,
   socket
   |> put_toast(:info, msg)
   |> push_patch(to: config.base_index_path)}
  ```

  The `push_patch` back to `base_index_path` closes the modal because `@live_action` resets.

### 6. Remove dead code

Once steps 3–5 are in place:

- `IndexActions.handle_import/3` is no longer called (verified earlier: only collection + wishlist called it; stats does not). Remove it.
- The old `handle_event("import", ...)` in both collection and wishlist LiveViews is gone (step 4).

### 7. Gettext

After implementation, run `mix gettext.extract` and `mix gettext.merge priv/gettext` to regenerate `.pot` / `.po` files. New strings to cover:

- "In cart"
- "Import %{count} record" / "Import %{count} records" (ngettext)
- "Your cart is empty"
- "Clear all"
- "Remove"
- "Importing %{count} record in the background..." / plural (matches barcode scan wording)
- "Error importing record"

Some (e.g. the background toast) may already exist from the barcode flow — reuse identical strings so translations don't duplicate.

## Files touched

- `lib/music_library_web/components/add_record.ex` — full rewrite of the render plus cart state/handlers (biggest change).
- `lib/music_library_web/live_helpers/index_actions.ex` — add `handle_cart_imported_single/2` and `handle_cart_imported_async/2`; remove `handle_import/3`.
- `lib/music_library_web/live/collection_live/index.ex` — remove old `handle_event("import", ...)`, add `handle_info/2` clauses, widen import modal.
- `lib/music_library_web/live/wishlist_live/index.ex` — same changes.
- `lib/music_library_web/components/core_components.ex` — add `width_class` attr to `structured_modal/1`.
- `lib/music_library/worker/import_from_musicbrainz_release_group.ex` — new file.
- `test/music_library_web/components/add_record_test.exs` — new or updated component tests (today's import flow tests likely live in the live-view tests; see below).
- `test/music_library_web/live/collection_live/index_test.exs` — update import-flow tests to go via cart (add-to-cart → import → assert).
- `test/music_library_web/live/wishlist_live/index_test.exs` — same.
- `test/music_library/worker/import_from_musicbrainz_release_group_test.exs` — new worker test modelled on `fetch_artist_info_test.exs` / `artist_refresh_wikipedia_data_test.exs` (existing worker test shape in the repo).
- `priv/gettext/*` — regenerated by `mix gettext.extract --merge`.

No migrations, no Oban config changes (the `:music_brainz` queue already exists), no JS hooks.

## Verification

1. `mise run dev:precommit` — format, Credo, Sobelow, ExSlop, tests. Must pass.
2. Manual browser checks with the dev server running:
   - **Small viewport** (narrow window): open Collection → "Add record" → search → add 3 items with different formats → cart shows as bottom tray; collapse/expand chevron works; "Import 3 records" enqueues (assert via Oban web `/dev/oban` or toast).
   - **`md:+` viewport**: same flow; cart sits as right column; dropdown doesn't clip.
   - **Single-item sync path**: add 1 item → click "Import 1 record" → button shows spinner → modal closes → lands on the new record's detail page → toast visible.
   - **Error path**: stub MusicBrainz to fail (or pick an invalid release) → error toast appears in the modal, modal stays open, cart preserved, `importing?` cleared.
   - **Dedup**: add same `{rg, format}` twice → no duplicate cart row. Add same `rg` with two different formats → two cart rows.
   - **Wishlist parity**: repeat the happy path from Wishlist index.
3. `mix test test/music_library/worker/import_from_musicbrainz_release_group_test.exs` — worker unit coverage.
4. `mix test test/music_library_web/live/collection_live/index_test.exs test/music_library_web/live/wishlist_live/index_test.exs` — updated feature tests for the cart flow, including `assert_enqueued` for 2+ items and `refute_enqueued` for the sync 1-item path.
5. `grep -R "handle_event(\"import\"" lib/ | grep -v stats_live` should return nothing, confirming removal.

## Open items deferred to implementation

- Exact Tailwind classes for the cart column (min/max heights, padding) — start with the defaults above, tweak in the browser.
- Dropdown `placement` on `md:` if right-edge clipping appears.
- Whether the empty-state deserves an illustration/icon or just text — copy-level only.
