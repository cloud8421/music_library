---
id: doc-36
title: "ML-231 Research: Add records to sets implementation routes"
type: other
created_date: "2026-07-12 17:24"
updated_date: "2026-07-12 17:38"
---

# ML-231 research: add records to sets

## Objective

Allow a record to be added to one or more record sets from `/collection`, `/wishlist`, `/collection/:id`, and `/wishlist/:id` through a modal, while preserving the user's current page context.

## Current state and constraints

- `MusicLibrary.RecordSets.add_record_to_set/2` adds one record to one set, appends it at `max(position) + 1`, rejects duplicates through the existing unique index on `(record_set_id, record_id)`, and reloads the full set.
- `MusicLibraryWeb.RecordSetLive.RecordPicker` implements the inverse workflow: from one set, search for and immediately add records. It cannot be reused directly because ML-231 starts from one record and chooses sets.
- Collection and wishlist listing action menus are shared by `RecordComponents.record_grid/1`, `record_list/1`, and private `record_action_links/1`. The same grid also appears on artist pages, so the new action must be explicitly supplied by the target listing pages rather than appearing where no picker route/event exists.
- Both detail pages use `RecordComponents.record_show_action_bar/1` and already load the record's current memberships through `LiveHelpers.RecordShow.assign_common_record/3` and `RecordSets.list_record_sets_for_record/1`.
- Existing route-backed modals use `:live_action`, `structured_modal/1`, and `JS.patch/1`. Index LiveViews use `apply_fallback_index/4` so direct modal URLs initialize their streams before rendering.
- Do not use `RecordSets.list_record_sets/1` for the picker unchanged: it preloads every item and record in every set. A picker needs only set metadata and whether the current record is already a member.
- Existing indexes support the picker without a migration: `(record_set_id, record_id)` for membership/duplicate checks, `record_id` for cross-set lookups, and `(record_set_id, position)` for append-position lookup.
- The current development database has 16 sets and 134 memberships (maximum 40 records in a set and 3 sets for one record). This is only a local baseline; the implementation should remain linear in the number of sets displayed rather than all records in those sets.

## Shared baseline for every viable route

- Add a reusable record-to-set picker LiveComponent rather than duplicating modal markup and mutation handling in four LiveViews.
- Show sets alphabetically, mark existing memberships as already added, and prevent duplicate submission. Existing memberships should not be removable because this task is specifically an add workflow.
- Load set metadata plus membership state with a fixed query count: either one query with an indexed `EXISTS` projection or two simple queries (all lightweight sets plus the current record's set IDs). Do not preload set items/records.
- Add an “Add to sets” action to both collection/wishlist grid and list menus and to both detail-page action menus.
- Handle no-set, already-in-all-sets, success, duplicate/race, and database-error states with translated text and accessible controls.
- Preserve listing search, page, page size, order, and display state when opening and closing the modal.

## Route 1 — Route-backed modal with immediate per-set additions

Add these modal routes:

- `/collection/:id/add-to-set` on `CollectionLive.Index`
- `/wishlist/:id/add-to-set` on `WishlistLive.Index`
- `/collection/:id/show/add-to-set` on `CollectionLive.Show`
- `/wishlist/:id/show/add-to-set` on `WishlistLive.Show`

The picker shows one action per available set. Selecting a set immediately calls the existing single-set mutation, marks that row as added, shows feedback, and leaves the modal open so further sets can be chosen.

### Advantages

- Simplest viable implementation and closest to the existing `RecordSetLive.RecordPicker` interaction.
- Reuses `add_record_to_set/2`; each click has an independent success/failure boundary, so there is no ambiguous partially failed batch.
- Route-backed state follows existing project modal conventions and supports direct links, browser back, and reliable close paths.

### Costs and risks

- “One or more” means repeated clicks rather than selecting several sets and submitting once.
- Each added set currently performs a max-position query, insert, and full-set reload. This is acceptable per click but wasteful if many sets are chosen; a lighter single-add context return could be added.
- The modal remains open after success, so users need a clear added state and explicit completion/close affordance.

## Route 2 — Route-backed modal with checkbox selection and one transactional submit

Use the same four modal routes, but render available sets as a Fluxon checkbox group. The user selects one or more sets and submits once. Add a dedicated context operation such as `RecordSets.add_record_to_sets/2` that treats the selection as one operation, ignores memberships created concurrently, computes append positions from indexed set-item data, and inserts all new memberships in a transaction.

### Advantages

- Most direct interpretation of selecting “one or more” sets.
- One confirmation action and one success message; better when records are commonly added to several sets.
- A dedicated bulk context boundary can use fixed-count queries and avoid calling the current preload-heavy single-add function once per selected set.
- Route-backed state remains consistent with existing modal architecture.

### Costs and risks

- More implementation and test work than Route 1: form state, validation, transaction semantics, idempotency, and bulk append-position handling.
- The context must define all-or-nothing behavior for real database failures while treating duplicate memberships caused by stale UI/concurrent actions as idempotent.
- Position allocation must be tested; the existing single-add max-position pattern already has a concurrency window, and the bulk implementation should not widen it.

## Route 3 — Event-driven checkbox modal without new routes

Mount the reusable picker in each of the four target LiveViews. An action pushes an event containing the record ID; the parent assigns the record and opens the modal. Closing it clears the picker state. The picker can use the same bulk operation described in Route 2.

### Advantages

- No router additions or modal URL variants.
- Listing query parameters remain untouched because no patch occurs.
- The component can be reused on all four pages.

### Costs and risks

- Diverges from the project's route-backed modal convention.
- Modal state is not linkable and browser Back does not close it.
- Four parents still need open/close plumbing or new shared helper callbacks; detail pages must explicitly refresh their membership list after saving because `handle_params/3` will not rerun.
- Server-controlled and client-controlled modal state must be synchronized on ESC/outside-click through `on_close` to avoid stale record/form state.

## Deferred route — Full membership editor

A modal could pre-check current memberships and apply both additions and removals as a synchronized final state. This is not recommended for ML-231: it expands an add action into destructive removal behavior, needs confirmation/error semantics for removals, and duplicates capabilities already available on record-set pages.

## Comparison

| Route                           | Multi-set interaction      | Project convention fit | Data-layer work                                     | Failure model                    | Relative complexity |
| ------------------------------- | -------------------------- | ---------------------- | --------------------------------------------------- | -------------------------------- | ------------------- |
| 1. Route-backed immediate add   | Repeated immediate actions | Strong                 | Reuse single-add; optional lightweight optimization | Independent per set              | Low                 |
| 2. Route-backed checkbox submit | Select many, submit once   | Strong                 | New transactional bulk operation                    | One idempotent batch             | Medium              |
| 3. Event-driven checkbox submit | Select many, submit once   | Weaker                 | Same bulk operation as Route 2                      | One idempotent batch             | Medium-high         |
| Full membership editor          | Add and remove in one save | Strong if route-backed | Synchronization operation                           | Mixed additive/destructive batch | High; out of scope  |

## Recommendation

Choose Route 2 if “one or more” means selecting several checkboxes and committing once; it best matches the requested interaction and existing route-backed modal architecture. Choose Route 1 if minimizing code and retaining independent per-set operations matters more than a single bulk submit. Route 3 has no compelling benefit in this codebase because avoiding four small route declarations creates more state synchronization and parent plumbing.

## Architectural and operational impact common to Routes 1–3

- **Schemas/migrations:** no schema or index migration expected.
- **Contexts:** `MusicLibrary.RecordSets` gains a lightweight picker query; Route 2/3 also gain a bulk add operation.
- **Routes:** four routes for Route 1/2; none for Route 3.
- **LiveViews/components:** shared listing/detail action components, both index LiveViews, both show LiveViews, and one new reusable LiveComponent are touched. Shared helpers should own repeated index/show loading behavior.
- **PubSub/supervision/external APIs:** no changes.
- **Performance:** picker rendering is O(S) in the number of record sets, with a fixed query count and O(S) transient component state. No query should load every record-set item. Route 1 uses O(K) mutation round trips for K user clicks; Route 2/3 should use fixed-count batch queries plus O(K) inserted rows. No external latency or paid service usage is introduced.
- **Benchmarking:** no ongoing benchmark is warranted for the current scale. A one-off query-count/`EXPLAIN QUERY PLAN` check is appropriate for the picker query and bulk mutation. Reconsider pagination/search and benchmark modal open latency if set counts approach the high hundreds or thousands.
- **Production changes:** standard deployment only; no environment variables, services, special migration handling, rollout steps, or paid-resource changes.
- **Documentation:** update `docs/architecture.md` only if a new reusable component/helper or new `RecordSets` responsibility materially changes the architecture map. `docs/project-conventions.md` and production docs should not need changes unless implementation establishes a new convention.

## Decision

Route 2 was selected: use route-backed checkbox modals with one transactional bulk submit. Existing memberships will be shown checked and disabled, preserving an additive-only workflow. The detailed implementation plan and acceptance criteria are recorded in ML-231.
