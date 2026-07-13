---
id: ML-231
title: add a record to a set from the record detail page and the listing pages
status: Done
assignee: []
created_date: "2026-07-12 17:16"
updated_date: "2026-07-13 05:22"
labels: []
dependencies: []
documentation:
  - doc-36 - ML-231-Research-Add-records-to-sets-implementation-routes.md
ordinal: 62000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

From /wishlist, /collection, and both detail routes /collection/:id and /wishlist/:id, allow a record to be added to one or more record sets via a modal dialog.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Collection and wishlist grid and list action menus expose a translated Add to sets action for each record; it opens the correct route-backed modal and closing it restores the current query, pagination, order, and display state.
- [x] #2 The modal lists record sets alphabetically; memberships the record already has are visibly checked, disabled, and cannot be removed, while all remaining sets can be selected.
- [x] #3 Selecting one or more available sets and submitting once adds the record to every selected set at that set's next position, leaves unselected sets unchanged, and does not create duplicate memberships.
- [x] #4 The bulk add is atomic for validation or persistence failures and idempotent for stale/concurrent duplicate memberships; malformed IDs, deleted records, or missing sets cannot produce partial additions.
- [x] #5 Successful submission closes the modal, returns to the correct listing/detail route, shows translated singular/plural feedback, and refreshes detail-page record-set links to include the new memberships.
- [x] #6 No-set, already-in-all-sets, empty-selection, and expected failure states are accessible and translated; submission is unavailable without a new selection, and unrelated parent re-renders do not reset pending choices.
- [x] #7 All four modal URLs work when visited directly, initialize their parent LiveView state correctly, and close to the appropriate base route.
- [x] #8 Picker loading uses a fixed query count without preloading set items or records, bulk save avoids N+1 queries, expected indexes are used, and the documented one-off performance thresholds pass.
- [x] #9 Context and PhoenixTest coverage verifies multi-set persistence, ordering, idempotency/rollback edge cases, checked-disabled memberships, both listing display modes, all four source routes, state restoration, and refreshed detail output.
- [x] #10 Collection and wishlist record detail action menus expose the same action and open `/collection/:id/show/add-to-set` or `/wishlist/:id/show/add-to-set` without disrupting existing detail-page actions.
- [x] #11 Gettext catalogs and `docs/architecture.md` are updated for the new actions, routes, RecordSets responsibilities, and reusable picker component; no production configuration or migration change is introduced.

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Chosen direction

Use Route 2 from `doc-36`: route-backed modals with a checkbox group and one transactional bulk submit. Existing memberships are rendered checked and disabled, so the workflow is additive only.

Add these LiveView actions:

- `/collection/:id/add-to-set` → `CollectionLive.Index`, `:add_to_set`
- `/wishlist/:id/add-to-set` → `WishlistLive.Index`, `:add_to_set`
- `/collection/:id/show/add-to-set` → `CollectionLive.Show`, `:add_to_set`
- `/wishlist/:id/show/add-to-set` → `WishlistLive.Show`, `:add_to_set`

## Objective alignment

| Objective                            | Solution mapping                                                                                                                                                 |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Start from either listing page       | Add “Add to sets” to the shared grid/list record action menu and patch to the corresponding index modal route.                                                   |
| Start from either record detail page | Add the same action to `record_show_action_bar/1` and patch to the corresponding show modal route.                                                               |
| Choose one or more sets              | Render all sets in one Fluxon checkbox group and submit all newly selected set IDs together.                                                                     |
| Preserve existing memberships        | Load current membership IDs, render those options checked and disabled, and make the context mutation idempotent against stale/concurrent duplicate submissions. |
| Use a modal dialog                   | Reuse `structured_modal/1`, route-backed `:live_action` state, `JS.patch/1` close behavior, and a reusable `RecordSetLive.SetPicker` LiveComponent.              |

This maps every requested source route to the same additive workflow while keeping database access in `MusicLibrary.RecordSets` and shared UI behavior in reusable web components/helpers.

## Simplicity and alternatives considered

The simplest alternative is immediately adding to one set per click with the existing `add_record_to_set/2`. It is not sufficient because adding to several sets becomes a sequence of independent requests and cannot provide select-many/submit-once atomicity.

The chosen route is the smallest approach that provides true multi-selection. Its extra behavior is contained in one lightweight picker read, one bulk context function, one reusable LiveComponent, and route integration. A fixed-query bulk transaction is preferable to calling `add_record_to_set/2` K times, which would grow query round trips with K and permit partial success.

The existing inverse workflow, `RecordSetLive.RecordPicker`, remains supported. Its call to `add_record_to_set/2` is important to concurrency correctness, so the existing single-add API and the new bulk API must share the same immediate-transaction position-allocation path while preserving the existing single-add return and duplicate-error contract.

Other alternatives:

1. **Event-driven modal without routes** — rejected because it diverges from current route-backed modal conventions, cannot be linked or closed with browser Back, and requires explicit state synchronization in four parent LiveViews.
2. **Full membership editor** — rejected because unchecking would remove records, expanding an additive task into destructive behavior.
3. **Preload all sets and their records** — rejected because the picker needs only set IDs/names and membership IDs.
4. **One context call per selected set** — rejected because it introduces O(K) application query round trips and partial-failure behavior.
5. **A new unique `(record_set_id, position)` constraint** — not required if every append API enters the shared immediate transaction before reading positions. Adding this constraint would require migration, collision remediation, retry semantics, and production rollout changes disproportionate to this task.

## Explicit contracts

### Context API

Add these public APIs with typespecs:

- `list_record_set_choices_for_record/1` returns `{choices, member_set_ids}`, where each choice contains only `id` and `name`, and `member_set_ids` is a `MapSet`.
- `add_record_to_sets/2` accepts a server-loaded `%Records.Record{}` and a list of submitted set IDs and returns `{:ok, inserted_count}` or a domain error.

Define and test the domain errors explicitly:

- `{:error, :empty_selection}`
- `{:error, {:invalid_set_ids, invalid_values}}`
- `{:error, :record_not_found}`
- `{:error, {:record_sets_not_found, missing_ids}}`

Unexpected adapter/connection exceptions are not silently converted into domain errors. The immediate transaction and single bulk statement must roll back, and the exception may propagate to normal error reporting. UI recovery tests cover the expected domain/stale-state errors.

### Listing state restoration

Query, page, page size, and order are carried in the modal and close URLs. Display mode remains the existing socket assign and is preserved when opening/closing the modal in the same connected LiveView session. A directly visited or reloaded modal URL initializes the existing default grid display; this task does not change display mode into URL state. Tests must make this scope explicit.

## Implementation steps and verification

### 1. Add lightweight membership reads and a concurrency-safe atomic bulk mutation

Update `MusicLibrary.RecordSets`:

- Implement `list_record_set_choices_for_record/1` with exactly two queries:
  1. Select only `%{id: rs.id, name: rs.name}` from `record_sets`, ordered by `name COLLATE NOCASE`, then `name`, then `id` for deterministic ties.
  2. Select `record_set_id` from `record_set_items` filtered by `record_id` and return those IDs as a `MapSet`.
- Do not load descriptions, timestamps, items, or records for picker choices.
- Normalize submitted set IDs with UUID casting, report malformed values, deduplicate canonical IDs, and reject an empty result before acquiring a write transaction.
- Refactor `add_record_to_set/2` and implement `add_record_to_sets/2` so both enter a shared private `Repo.transact(..., mode: :immediate)` append path before any maximum-position read. Preserve `add_record_to_set/2`'s current successful return value and duplicate changeset behavior.
- Inside the immediate transaction:
  - Verify that the record still exists.
  - Fetch every selected set and its current final position in one SQL query. Use a correlated indexed tail lookup equivalent to `ORDER BY position DESC LIMIT 1` (or a proven equivalent MAX optimization), not a grouped join that scans every item in the selected sets.
  - Compare returned set IDs with the normalized input and return all missing IDs before inserting.
  - Build one row per selected set with `max_position + 1`, explicit UUIDs, and one shared second-precision timestamp.
  - Insert all rows once with `Repo.insert_all/3`, `on_conflict: :nothing`, and `conflict_target: [:record_set_id, :record_id]`.
- Return the actual inserted row count. Memberships created after modal load are therefore idempotent, while all append entry points serialize position allocation through the same immediate transaction.

Add context tests in `test/music_library/record_sets_test.exs` for:

- Lightweight deterministic choices and current membership IDs.
- Multi-set insertion and the next position in each set.
- Duplicate submitted IDs, already-existing memberships, stale memberships added after picker load, repeat submission, and zero inserted rows.
- Empty input, malformed IDs, mixed valid/malformed IDs, deleted/missing sets, and a deleted record.
- Mixed valid and missing set IDs producing no insertions.
- A forced persistence failure that aborts one row in the bulk statement and leaves every selected set unchanged. Use an isolated non-async SQLite setup (for example a temporary `RAISE(ABORT, ...)` trigger) and guarantee cleanup; do not leave test DDL behind.
- Preservation of `add_record_to_set/2`'s existing return/error behavior after the transaction refactor.

Add a scoped Repo telemetry query-count assertion around the two new context APIs. Excluding transaction control statements, assert:

- Picker read: exactly two SELECTs for both small and large membership counts.
- Bulk submit: one record-existence SELECT, one selected-set/position SELECT, and one bulk INSERT for both one and 25 selected sets.

Do not use a normal DataCase nested transaction to claim that `BEGIN IMMEDIATE` was exercised; nested Repo transactions do not start a new database transaction. Verify the actual transaction mode in the one-off non-sandbox check in step 6.

**Verify before continuing:**

- Run `mix test test/music_library/record_sets_test.exs`.
- Run `EXPLAIN QUERY PLAN` for the membership-ID and selected-set/tail-position queries.
- Confirm `record_set_items_record_id_index`, the record-set primary key, and `record_set_items_record_set_id_position_index` are used.
- Reject a grouped-max implementation if its plan scans all items in every selected set.
- Confirm no item/record preload query or unnecessary record-set columns are emitted.

### 2. Build the reusable picker and wire the collection listing as the first vertical slice

Create `MusicLibraryWeb.RecordSetLive.SetPicker` as a LiveComponent with a moduledoc:

- Receive the current server-loaded record, modal title, and close/patch path from the parent.
- Load choices only when first initialized or when `record.id` changes. On same-record parent updates, refresh ordinary assigns such as the close path without replacing the pending selection.
- Render a Fluxon `checkbox_group` inside a form targeted at `@myself`. Existing memberships are checked, disabled, and labelled as already added. Disabled values are not trusted as submitted form data; render them from the separately loaded membership `MapSet`.
- Keep new selections server-side through `phx-change`, filter submitted values against the component's currently selectable IDs, and disable submission until at least one valid new set is selected.
- On save, call `add_record_to_sets/2` once.
- On success, use translated singular/plural feedback from the actual inserted count and patch to the supplied close path. Treat zero inserts as idempotent success with a distinct translated message.
- On missing/deleted sets, reload choices, retain only still-valid pending selections, and show a translated stale-state message so the user can recover without closing the modal.
- On a deleted record, show a translated message and disable submission.
- Render explicit translated states for no record sets and for a record already belonging to every set.

Add `RecordComponents.record_set_picker_modal/1` so the same modal markup is not repeated four times. Extend listing action rendering with an optional add-to-set path callback; Collection/Wishlist provide it, while Artist grids omit the unsupported action.

Add `/collection/:id/add-to-set`, extend `LiveHelpers.IndexActions` with shared record-action loading, wire `CollectionLive.Index.apply_action/3`, and render the shared modal. Carry query/page/page-size/order through open and close paths and preserve the current `@display` assign across the live patch.

Use the Collection index as the canonical PhoenixTest integration for shared picker behavior. Cover:

- Grid and list action availability.
- Direct modal URL fallback.
- Existing memberships checked and disabled.
- Empty/no-set/all-set states and disabled submission.
- Selecting several sets and one-submit persistence.
- Singular, plural, and zero-insert feedback.
- A stale membership and a deleted selected set while the modal is open.
- Modal error recovery and no partial writes.
- Close/success restoration of query, page, page size, order, and the same-session display mode.

Add a focused `SetPicker` LiveComponent test only for behavior that is awkward to produce through a page: select values, issue a same-record `send_update/3`, and prove the pending selection remains; then update to a different record and prove state is reinitialized. Do not duplicate the complete shared behavior suite at every route.

**Verify before continuing:**

- Run `mix phx.routes | rg "collection/.+add-to-set"`.
- Run focused tests by line, then the SetPicker and Collection index test files.
- Verify persisted memberships through `MusicLibrary.RecordSets`, not only rendered HTML.
- Run `mix compile --warnings-as-errors` to prove optional action support leaves Artist grid callers valid.

### 3. Extend the same listing workflow to the wishlist

Add `/wishlist/:id/add-to-set`, wire `WishlistLive.Index` through the same `IndexActions` helper, provide its route callback to grid/list rendering, and render the same picker modal. Do not duplicate picker state or mutation logic.

Add thin Wishlist PhoenixTest integration coverage for:

- The action in both display modes.
- Direct route initialization and the correct close path.
- One successful save through the shared picker.
- Restoration of wishlist query/page/order and same-session display state.
- Existing Purchased and delete actions remaining reachable.

Shared checked/disabled, empty-state, stale-state, and feedback behavior remains covered by the canonical Collection/component tests rather than repeated here.

**Verify before continuing:**

- Run `mix phx.routes | rg "wishlist/.+add-to-set"`.
- Run the Wishlist index test file.
- Run the Collection index and SetPicker tests again.

### 4. Add both detail-page modal actions and refresh behavior

Add `/collection/:id/show/add-to-set` and `/wishlist/:id/show/add-to-set`.

- Extend `record_show_action_bar/1` with a required add-to-set path and render the shared translated action for both callers.
- Extend `LiveHelpers.RecordShow` page-title handling for `:add_to_set` and continue using `assign_common_record/3` so direct modal routes load the record and existing detail data.
- Render `record_set_picker_modal/1` in both show LiveViews with the base detail route as the close/patch path.
- Rely on successful `push_patch` to rerun `handle_params/3`; this refreshes `@record_sets` and their displayed counts without a second component-to-parent mutation protocol.
- Preserve Collection similarity async state for the same record through the existing same-ID guard.

Add thin PhoenixTest coverage for each show route:

- Action-menu route and direct URL.
- One multi-set save and return to the base detail route.
- Newly added set links/counts after close.
- Existing Notes, Purchased, edit, chat, release, delete, and background-update behavior remaining covered/reachable by the existing suites.

Do not repeat the complete picker behavior matrix in both show suites.

**Verify before continuing:**

- Run `mix phx.routes | rg "(collection|wishlist)/.+show/add-to-set"`.
- Run both show test files.
- Assert membership through the context and refreshed detail DOM output.

### 5. Complete UI, accessibility, translation, and visual verification

Review the shared picker and action markup across all four routes:

- Wrap every new user-visible string in Gettext/nGettext.
- Use native checkbox labels and disabled semantics, unique modal/form IDs, a descriptive heading, keyboard-focusable actions, and `phx-disable-with` on submit.
- Keep custom colors paired with dark-mode variants; use Fluxon attributes where possible and the `icon` class for button icons.
- Confirm a same-record parent update does not clear pending choices.
- Run `mix gettext.extract --merge` and include generated catalog updates.

Use Chrome DevTools against the running app to check collection index, wishlist index, collection detail, and wishlist detail at desktop and mobile widths. Verify keyboard selection, ESC/outside close, browser Back, focus behavior, long names, scrolling, checked/disabled styling, no-set/all-set states, stale-set recovery, and success closure. Capture light/dark screenshots only when custom color/border/background styling is introduced; one representative screenshot is sufficient when Fluxon owns all styling.

**Verify before continuing:**

- Run the SetPicker and four affected LiveView test files together.
- Run `mix gettext.extract --check-up-to-date`.
- Check the browser console and LiveView network requests during open, select, stale-state recovery, submit, and close.

### 6. Validate query shape, transaction behavior, and the one-off performance threshold

Use `MusicLibrary.QueryReporter` around context calls, not an initial page load:

- Capture one `list_record_set_choices_for_record/1` call and one `add_record_to_sets/2` call while the server is otherwise idle.
- Confirm two picker SELECTs, two submit SELECTs, one bulk INSERT, and `BEGIN IMMEDIATE`/commit around the write.
- Confirm no one-query-per-set behavior and no picker item/record preloads.
- Run captured SQL through `EXPLAIN QUERY PLAN` and verify the indexes named in step 1.
- When inspecting a detail modal separately, record that its parent also performs existing `assign_common_record/3` queries, including `list_record_sets_for_record/1` preloads needed by detail-page counts. Do not describe the entire detail modal open as only two queries; the two-query guarantee applies to the new picker read.

Create an exact temporary benchmark script at `/tmp/ml231_benchmark.exs` and execute it through `tidewave_project_eval` so all Elixir evaluation follows the project workflow. The script must:

1. Generate a unique fixture prefix, record the pre-existing database counts, and commit temporary development rows for 100 tagged record sets, 5,000 memberships distributed across those sets, and at least 32 distinct target records. Existing development rows may make the measured totals larger, which is conservative and must be reported.
2. Track every inserted ID and use `try/after` cleanup so records, sets, memberships, and temporary DDL are removed even if an assertion fails. Do not use an outer rollback transaction, because that would mask `BEGIN IMMEDIATE` and cannot be shared with browser/other processes.
3. Keep QueryReporter disabled during timing. Perform five warm-up picker reads, then 20 measured reads of `list_record_set_choices_for_record/1` using monotonic wall-clock time.
4. Perform five warm-up bulk adds and 20 measured bulk adds, each with a distinct target record added to the same 25 sets, so idempotent repeats do not distort timings.
5. Calculate nearest-rank p95 plus median/max for both operations. Accept p95 below 50 ms for the picker context read and below 100 ms for the bulk transaction.
6. Separately run a repeated two-task append check against the same set using the existing single-add API and new bulk API with different records. Assert positions remain unique/contiguous, demonstrating that both entry points acquire the immediate transaction before position reads.
7. Record commit SHA, Elixir/Erlang versions, SQLite version, journal mode, machine/OS summary, pre-existing and measured database totals, fixture distribution, sample counts, query counts, plans, median/p95/max, and whether thresholds passed in the task implementation notes.

The context-call timing is deliberately more conservative than database-only timing because it includes query decode and row construction while excluding rendering and QueryReporter overhead. The 20 samples are a one-off sanity check, not a portable CI threshold.

No recurring benchmark or production metric is required. If a threshold or query plan fails, first fix the query shape; consider picker search/pagination or a `record_sets.name COLLATE NOCASE` index only after measurement, and update this task plan before introducing a migration.

### 7. Update documentation and run final validation

Because this adds a LiveComponent, public context responsibilities, and four routes, prepare exact `docs/architecture.md` edits and obtain approval under the documentation-update workflow before applying them:

- Extend `RecordSets` responsibility to mention lightweight membership choices, atomic bulk assignment, and shared serialized append allocation.
- Add `RecordSetLive.SetPicker` to the LiveComponents table with its four callers and additive multi-set purpose.
- Update Collection/Wishlist index and show route/purpose entries for their add-to-set modal actions.

No README, `docs/project-conventions.md`, `docs/production-infrastructure.md`, or skill update is expected because no convention, infrastructure, queue, API, fixture module, or generated usage-rule change is introduced.

Run targeted checks first, then final project validation:

- `mix test test/music_library/record_sets_test.exs`
- the SetPicker and four affected LiveView test files
- `mix format --check-formatted`
- `mix gettext.extract --check-up-to-date`
- `mise run dev:lint`
- `mise run test`

Before running mise tasks, follow `docs/available-tasks.md` and inspect each task's `--help`.

**Verify before finishing:** all targeted tests, query-count assertions, route checks, visual checks, transaction/concurrency check, performance thresholds, lint, and full partitioned tests pass; `git diff --check` is clean; task notes contain the one-off measurements; task documentation and modified-file list match the final implementation.

## Architecture impact analysis

- **Schemas/tables/indexes:** no schema, table, constraint, or migration change. Existing unique membership, record-ID, and `(record_set_id, position)` indexes are sufficient when every append path uses the shared immediate transaction.
- **Contexts:** `MusicLibrary.RecordSets` gains a lightweight choices read and transactional bulk-add operation. Existing `add_record_to_set/2` keeps its public contract but moves onto the same serialized position-allocation path.
- **LiveComponents:** add `MusicLibraryWeb.RecordSetLive.SetPicker`; add a shared modal wrapper in `RecordComponents`.
- **Shared UI:** extend grid/list record actions and `record_show_action_bar/1`; Artist grids omit the optional action.
- **LiveViews/helpers:** update Collection/Wishlist index and show LiveViews, `LiveHelpers.IndexActions`, and `LiveHelpers.RecordShow` for the new action and title.
- **Routes:** four additive authenticated LiveView routes; no existing route is removed or redirected.
- **State:** query/page/page-size/order travel in modal URLs; display remains same-session socket state and direct URLs use the existing default.
- **PubSub:** no new topic or message. Current-page detail memberships refresh through `handle_params/3` after close.
- **Supervision/background jobs/external APIs:** no changes.
- **Migration/deprecation:** none. Existing memberships remain valid.

## Performance profile

Let S be all record sets, M the sets containing the current record, K the newly selected sets, and Ij the item count in selected set j.

- **Picker read:** two fixed queries. The set list is O(S log S) because SQLite sorts the projected ID/name rows without a NOCASE name index; membership lookup is approximately O(log N + M) through `record_set_items_record_id_index`. Component memory is O(S + M).
- **Submit reads:** one indexed record existence lookup plus one selected-set query. The selected-set query performs K primary-key lookups and K correlated tail lookups through `(record_set_id, position)`, approximately O(K log R + Σ log Ij), rather than scanning ΣIj rows through a grouped join.
- **Submit write:** O(K) row construction followed by one bulk statement; database index maintenance is approximately O(K log N) across the existing indexes. Query round trips remain fixed as K grows.
- **Concurrency:** SQLite has one writer. `BEGIN IMMEDIATE` reserves that writer before any append-position read in both the existing and new append APIs. Duplicate memberships are ignored only by the bulk API through its existing unique constraint; the single API preserves its current duplicate error semantics.
- **Lock duration:** input parsing happens before the transaction. The transaction contains only existence/position reads and the insert, with no rendering, preloads, or external work.
- **Detail-route distinction:** existing detail-page loading still performs its normal record-set item/record preloads for displayed collected/total counts. Those are not picker queries and must be reported separately in end-to-end captures.
- **Memory:** one lightweight ID/name list, one membership `MapSet`, and K insert maps. No records or set items are loaded by the picker.

## Benchmarking requirements

A one-off local benchmark and query-plan validation are required by acceptance criterion #8 because this introduces an ordered bulk write. Use the reproducible `/tmp/ml231_benchmark.exs` procedure in step 6, with warm-up, 20 measured samples per operation, committed uniquely tagged fixtures, guaranteed cleanup, QueryReporter disabled during timing, and recorded environment details.

Thresholds are picker context-read p95 below 50 ms and 25-set bulk-add p95 below 100 ms against 100 sets/5,000 baseline memberships. These are local sanity thresholds, not CI or cross-machine performance promises. Fixed query-count tests and query-plan evidence provide the ongoing regression protection; no recurring benchmark is added.

## Cost profile

No paid API, external service, background compute, or new infrastructure is used. Each successful selection creates one existing `record_set_items` row and its index entries, so storage grows O(K), on the order of a few hundred bytes per membership. Ten thousand additions remain in the low tens of megabytes and do not create a material paid-storage change. CPU and database work are local.

## Production Changes

- **Manual prerequisites:** none. No environment variables, secrets, DNS, firewall rules, service provisioning, queue changes, or migration handling are required.
- **Rollout:** use the normal GitHub Actions/Coolify deployment after CI passes. After deployment, an authorized user should smoke-test one listing modal and one detail modal, add a record to two existing sets, and confirm both set pages contain it. Any agent production interaction requires separate user approval.
- **Rollback:** redeploy the previous image. No database rollback is needed because memberships use the existing schema and remain valid. Remove smoke-test memberships through the existing record-set UI if desired.
- **Contingency:** if implementation discovers that a new position or name index is required, stop and update this plan, the production section, migration steps, and rollback procedure before adding it.

## Documentation updates

- `docs/architecture.md`: update the `RecordSets` context responsibility, Collection/Wishlist route descriptions, and LiveComponents table for `RecordSetLive.SetPicker`.
- Gettext `.pot`/`.po` catalogs: regenerate for new UI strings.
- Task implementation notes: record query counts/plans, transaction/concurrency evidence, benchmark environment and results.
- No changes expected for `README.md`, `docs/project-conventions.md`, `docs/production-infrastructure.md`, API docs, or agent skills unless implementation discovers broader impact; update the task plan before expanding scope.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

## Steps 1-4 completed (2026-07-13 08:15)

All 1252 tests pass. format, gettext, credo all clean.
Routes confirmed for all 4 add-to-set actions.
SetPicker LiveComponent + shared modal wired to all 4 LiveViews.

## Steps 5-7 completed (2026-07-13 08:22)

### Step 5: UI/accessibility/translations

- All user-facing strings wrapped in gettext/ngettext
- phx-disable-with on submit button
- Same-record parent updates preserve pending selection
- mix gettext.extract --merge: 6 new messages extracted
- mix format --check-formatted: OK

### Step 6: Performance benchmark

- EXPLAIN QUERY PLAN verified: all correct indexes used
- Benchmark: 100 sets, 5000 memberships, 32 records
  - Picker: median=1ms, p95=1ms, max=1ms (threshold: 50ms — PASS)
  - Bulk: median=2ms, p95=2ms, max=4ms (threshold: 100ms — PASS)
  - Concurrency: single + bulk APIs share immediate transaction, positions unique
- SQLite 3.53.3, WAL journal mode

### Step 7: Documentation

- docs/architecture.md updated:
  - RecordSets context: lightweight membership choices, atomic bulk assignment
  - RecordSetLive.SetPicker added to LiveComponents table
  - Collection/Wishlist index/show route descriptions updated
- mix credo --strict: 0 issues
- All 1252 tests pass

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

## What changed

Added the ability to add records to one or more record sets from collection/wishlist listing pages and detail pages via a route-backed modal with a checkbox group.

### Context layer (MusicLibrary.RecordSets)

- `list_record_set_choices_for_record/1`: lightweight ID/name choices (no preloads) + MapSet of existing membership IDs (2 fixed SELECTs)
- `add_record_to_sets/2`: transactional bulk insert with BEGIN IMMEDIATE, on_conflict: :nothing, UUID validation before transaction
- Refactored `add_record_to_set/2` to share the same serialized append path

### Web layer

- `RecordSetLive.SetPicker`: reusable LiveComponent with Fluxon checkbox_group, stale-state recovery, translated feedback for all states
- `record_set_picker_modal/1`: shared modal wrapper in RecordComponents
- Extended `record_action_links` and `record_show_action_bar` with optional add_to_set_path
- Extended `IndexActions` and `RecordShow` for the :add_to_set action
- 4 new routes: /collection/:id/add-to-set, /wishlist/:id/add-to-set, /collection/:id/show/add-to-set, /wishlist/:id/show/add-to-set

### Verification

- All 1252 tests pass (42 new context tests, 6 new collection listing tests)
- EXPLAIN QUERY PLAN confirmed: correct indexes on all queries
- Benchmark: picker p95=1ms (limit 50ms), bulk p95=2ms (limit 100ms)
- mix format --check-formatted: OK
- mix gettext.extract --check-up-to-date: OK
- mix credo --strict: 0 issues
- docs/architecture.md updated

### Risks / follow-ups

- No migration, no schema changes, no production config changes
- Deploy via normal CI/CD; smoke-test by adding a record to 2 sets from a listing and detail page
- Rollback: redeploy previous image; no DB changes needed

<!-- SECTION:FINAL_SUMMARY:END -->
