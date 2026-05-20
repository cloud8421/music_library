---
id: ML-192
title: Add high-value behavioral test coverage
status: To Do
assignee: []
created_date: "2026-05-20 17:19"
updated_date: "2026-05-20 21:54"
labels:
  - testing
  - coverage
dependencies: []
documentation:
  - docs/architecture.md
  - docs/project-conventions.md
  - .agents/skills/testing/SKILL.md
  - .agents/skills/ui-framework/SKILL.md
  - .agents/skills/sqlite-optimization/SKILL.md
priority: high
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Increase coverage where current tests would catch meaningful regressions in user-facing workflows and core data transformations. Focus on the high-value gaps identified from the coverage triage: RecordForm genre and cover-search behavior, BarcodeScanner component state and import branches, Notes component create/update/read-edit behavior, ScrobbleRules subset application, and Assets.Image conversion/error handling. Avoid tests that only assert markup exists without exercising behavior.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Record editing tests cover genre search suggestions, adding a new normalized genre, preventing duplicate/blank genres, and removing an existing genre through the LiveComponent path.
- [ ] #2 Record editing tests cover Brave cover search success, search failure with a friendly message, selecting a search result, and persisting the downloaded cover hash on the record.
- [ ] #3 Barcode scanner tests cover a scan failure toast, removing one scanned result, clearing all scanned results, and the 2+ new-release async import branch including expected enqueued import jobs.
- [ ] #4 Notes component tests cover creating a new record or artist note, rendering an existing note in read mode, updating note content, and persisting the result through the Notes context.
- [ ] #5 Scrobble rules tests prove apply_all_rules/1 only updates the supplied track subset and leaves non-supplied matching tracks unchanged.
- [ ] #6 Assets image tests cover convert/3 same-format passthrough, successful JPEG/WebP conversion as supported by the app, and invalid image data returning an error tuple.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Read `docs/architecture.md`, `docs/project-conventions.md`, `.agents/skills/testing/SKILL.md`, and the relevant UI/SQLite guidance before changing tests.

2. **Add `RecordForm` genre behavioral coverage** through existing record edit paths in `test/music_library_web/live/collection_live/show_test.exs` and/or `test/music_library_web/live/wishlist_live/show_test.exs`. Prefer PhoenixTest, using `unwrap/2` + LiveViewTest only for non-standard click targets (Fluxon custom selects, `<li>` elements with `phx-click`). The record edit form is reached via `click_link("Edit")` from either show page and renders the `RecordForm` LiveComponent. Cover genre search suggestions (type into `#genre-input`, assert `#genre-suggestions` list items appear), creating a normalized new genre (click "Create" suggestion, assert badge appears), duplicate/blank genre no-ops (attempt adding same genre twice, assert no duplicate badge; attempt adding empty string, assert badges unchanged), and removing an existing genre (click badge's remove icon, assert badge disappears). Assert both visible form state and persisted record state through `MusicLibrary.Records.get_record!/1` after form save.

3. **Add `RecordForm` cover-search/download coverage** through the same edit path. The `RecordForm` uses `start_async` for both BraveSearch image search and image download, which runs in a separate Task process. `Req.Test.stub/2` stores stubs per-process by default and will not be visible inside the Task. **Use `mode: :global`** on all BraveSearch stubs to make them available across process boundaries:

   ```elixir
   # Successful search stub
   Req.Test.stub(BraveSearch.API, fn conn ->
     Req.Test.json(conn, %{
       "results" => [
         %{
           "thumbnail" => %{"src" => "https://example.com/thumb1.jpg"},
           "properties" => %{
             "url" => "https://example.com/full1.jpg",
             "width" => 800, "height" => 600
           },
           "title" => "Test Cover 1", "source" => "example.com"
         },
         %{
           "thumbnail" => %{"src" => "https://example.com/thumb2.jpg"},
           "properties" => %{
             "url" => "https://example.com/full2.jpg",
             "width" => 1024, "height" => 1024
           },
           "title" => "Test Cover 2", "source" => "example.com"
         }
       ]
     })
   end, mode: :global)

   # Search failure stub
   Req.Test.stub(BraveSearch.API, fn conn ->
     conn
     |> Plug.Conn.put_status(429)
     |> Req.Test.json(conn, %{"error" => "Rate limit exceeded"})
   end, mode: :global)

   # Image download stub
   Req.Test.stub(BraveSearch.API, fn conn ->
     Plug.Conn.send_resp(conn, 200, Image.fallback_data())
   end, mode: :global)
   ```

   **Important:** Register `on_exit` cleanup to remove global stubs after each test to maintain test isolation:

   ```elixir
   on_exit(fn ->
     Req.Test.stub(BraveSearch.API, nil, mode: :global)
   end)
   ```

   Test flow: navigate to edit form → type query into cover search input → click "Search" button → call `render_async()` to wait for the async task → assert cover search result thumbnails render in `#cover-search-results` → click a result thumbnail → call `render_async()` again to wait for download async → assert success toast and verify `record.cover_hash` changed via `MusicLibrary.Records.get_record!/1`. For search failure: stub an error response, click search, call `render_async()`, and assert the friendly error text appears in the `p.text-red-600` selector containing "Search failed". For selecting a search result: stub both search and download, verify the downloaded cover hash is persisted on the record and an asset exists via `MusicLibrary.Assets.get(hash)`.

4. **Add `BarcodeScanner` coverage** in `test/music_library_web/live/collection_live/index_test.exs` under the existing `"Add via barcode scan"` describe block (or a new describe block). Use `trigger_hook/3` to simulate scan events, following the existing pattern in that file:
   - **Scan failure toast**: Stub `MusicBrainz.API` to return a `Req.Test.transport_error(conn, :timeout)`, trigger `trigger_hook("#barcode-scanner", "barcode_scanned", %{"number" => "123"})`, assert error toast appears (matching `gettext("Failed to search release for barcode %{number}", number: "123")`).
   - **Remove one scanned result**: Stub a successful scan, trigger hook, assert cart item appears. Trigger `render_hook` with `"remove_result"` event and `%{"number" => "123"}`, assert that item is removed while other items remain.
   - **Clear all scanned results**: Add multiple scan results, trigger `render_hook` with `"clear_results"`, assert all cart items are gone.
   - **2+ new-release async import branch**: Add 2+ new scan results, click `"Add N releases"` button. Assert `assert_enqueued(worker: MusicLibrary.Worker.ImportFromMusicbrainzRelease, args: %{"release_id" => _, "format" => _, "purchased_at" => _, "selected_release_id" => _})` with one job per new scan result. Assert no `Records.Record` rows were synchronously inserted via `MusicLibrary.Repo.all(Record)`.

   For the successful scan stub, follow the existing pattern in the `"Add via barcode scan"` test that stubs `MusicBrainz.API` for both the barcode search and the release/release-group endpoints. The plan only needs the barcode search path for scan-result display; full import requires release/release-group/cover stubs as well.

5. **Add `Notes` component coverage** through the `test/music_library_web/live/collection_live/show_test.exs` record show page. The Notes component is rendered as a Fluxon `<.sheet>` dialog opened via `phx-click={MusicLibraryWeb.Components.Notes.open("record-notes-sheet")}` from a standard `<button>` with text "Notes". Use `click_button("Notes")` to open the sheet. After opening:
   - **Creating a note**: The sheet opens in "edit" mode (tab "Edit" active) when no note exists. Fill in the textarea via `fill_in` or `unwrap` with `form/3` + `render_change/1`, click "Save", assert success toast and persistence via `MusicLibrary.Notes.get_note(:record, record.musicbrainz_id)`.
   - **Reading an existing note**: Pre-create a note via `Notes.create_note/2`, then reopen the sheet. Assert the "Read" tab is active and content is rendered.
   - **Editing a note**: Switch to "Edit" tab via `click_button("Edit")`, modify content, save, assert persistence.
   - **Persistence verification**: After create/update, call `MusicLibrary.Notes.get_note/2` to verify the note exists with expected content and entity.

   If `click_button("Notes")` targeting the sheet-open button does not work (e.g., the button is inside a scoped container), use `unwrap` with `element/2` + `render_click/1` as fallback. The `assert_has` selectors should target content inside the `.sheet` container.

6. **Add a `ScrobbleRules.apply_all_rules/1` subset context test** in `test/music_library/scrobble_rules_test.exs` under the existing `"rule application"` describe block. Create:
   - An enabled album rule matching "Test Album"
   - Two tracks with `album.title == "Test Album"` but different `scrobbled_at_uts` values (set explicitly to avoid SQLite second-precision ordering issues, per testing skill)
   - One track kept outside the supplied list (the non-supplied matching track)

   Call `apply_all_rules([supplied_track])` and verify:
   - The supplied track's `album.musicbrainz_id` was updated to the rule's target
   - The non-supplied matching track's `album.musicbrainz_id` remains unchanged

7. **Add `Assets.Image.convert/3` tests** in `test/music_library/assets/image_test.exs`. Use `Image.fallback_data/0` (~2KB JPEG, fast to process):
   - **Same-format passthrough**: `assert {:ok, data} = Image.convert(fallback_data, "image/jpeg", "image/jpeg")` and `assert data == fallback_data` (returns original binary unchanged, no Vips processing).
   - **JPEG → WebP conversion**: `assert {:ok, webp_data} = Image.convert(fallback_data, "image/jpeg", "image/webp")` and assert `webp_data != fallback_data` (different binary, successfully converted by libvips).
   - **Invalid image data**: Pass an arbitrary binary (e.g., `"not an image"`) and assert `{:error, _reason}` with a specific error tuple shape (Vix returns an error struct on invalid input).

8. **Keep the implementation test-only.** Do not refactor production code unless a new test exposes an actual bug; if a production fix is needed, pause and update the plan before continuing.

## Performance profile

- No production runtime performance changes are expected because this task adds behavioral tests only.
- Keep test runtime reasonable: use existing fixtures/fallback image data (`Image.fallback_data/0`), avoid real network calls (all external APIs stubbed with `Req.Test`), keep image conversions minimal (Vix operations on ~2KB images are fast), and prefer targeted LiveView interactions over full end-to-end import flows unless required by an acceptance criterion.

## Benchmarks

- Benchmarks are not required for the planned test-only implementation.
- Reconsider only if production image-processing, SQL, or import logic changes during implementation.

## Paid resources / external calls

- No paid resources should be used.
- All external API interactions, including BraveSearch and MusicBrainz, must be stubbed with `Req.Test`; no live API calls should occur.
- BraveSearch stubs use `mode: :global` to cross the `start_async` Task process boundary and must be cleaned up in `on_exit` to maintain test isolation.

## Production / manual infrastructure steps

- None expected. No environment variables, provisioning, deployment configuration, or manual production actions are required.

## Documentation

- No documentation updates are expected for test-only coverage.
- **Exception:** The `mode: :global` Req.Test stub pattern for APIs consumed via `start_async` Tasks is new to this project. If this pattern is used in the implementation, add a section to `.agents/skills/testing/SKILL.md` under "API Stubs (Req.Test)" documenting when and how to use global stubs, the cleanup requirement, and the interaction with `start_async`/`render_async`.

## Verification

1. Run targeted tests for every touched file, for example:
   - `mix test test/music_library_web/live/collection_live/show_test.exs test/music_library_web/live/collection_live/index_test.exs test/music_library/scrobble_rules_test.exs test/music_library/assets/image_test.exs`
   - Include `test/music_library_web/live/artist_live/show_test.exs` or `test/music_library_web/live/wishlist_live/show_test.exs` if Notes or RecordForm coverage lands there.
2. Run `mise run dev:lint` for formatting/static checks after Elixir test changes.
3. Run `mise run test` as the CI-equivalent full suite when feasible. If it is skipped because of time or environment limits, record that explicitly in the task notes/final summary with the targeted commands that did pass.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

## Plan review (2026-05-20)

Reviewed against 10 review criteria. Five issues found, all addressed:

1. **Critical** — Fixed `Req.Test` stub process boundary gap. BraveSearch is called via `start_async` Tasks; `Req.Test.stub/2` is per-process. Plan now specifies `mode: :global` with `on_exit` cleanup.
2. **Medium** — Added Notes sheet interaction details: button text, tab names, fill_in/unwrap fallback strategy.
3. **Medium** — Added full BraveSearch stub response shapes (search result map, download binary) and the `render_async()` calls needed after async triggers.
4. **Minor** — Step 4 now cross-references the existing barcode scan test as a pattern for MusicBrainz.API stubbing.
5. **Advisory** — Documentation section now mandates updating the testing skill if `mode: :global` stubs are introduced.
<!-- SECTION:NOTES:END -->
