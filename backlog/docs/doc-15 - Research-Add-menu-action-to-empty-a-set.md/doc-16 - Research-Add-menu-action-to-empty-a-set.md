---
id: doc-16
title: "Research: Add menu action to empty a set"
type: specification
created_date: "2026-05-09 17:58"
---

# Research: Add menu action to empty a set

## Current state

Both the index (`RecordSetLive.Index`) and show (`RecordSetLive.Show`) views have a dropdown menu on each set with two actions:

- **Edit** — `dropdown_link` that patches to the edit form
- **Delete** — `dropdown_button` with `phx-click="delete_set"` and a `data-confirm` prompt

The `RecordSets` context currently provides `remove_record_from_set/2` for removing individual records, and `delete_record_set/1` for deleting the entire set (including its items via the `has_many` association's `on_delete` behavior). There is no function to remove all items from a set while keeping the set itself.

## Approach

Since the user has confirmed this is a straightforward feature, there's a single clear implementation route:

### 1. Context: Add `empty_record_set/1`

Add a new function to `MusicLibrary.RecordSets` that deletes all `RecordSetItem` rows for a given set in a single DELETE query, then returns the reloaded (now empty) record set. This avoids N+1 deletion and keeps the set metadata intact.

### 2. UI: Add "Empty" action to both dropdowns

In both `index.ex` and `show.ex`, add a new `dropdown_button` with:

- Text: `gettext("Empty")`
- `phx-click="empty_set"`
- `data-confirm` for safety: `gettext("Remove all records from this set?")`

And add the corresponding `handle_event("empty_set", ...)` handler in each LiveView.

### 3. Tests

- Unit test for `RecordSets.empty_record_set/1`
- LiveView test for the "empty_set" event in the index view
- LiveView test for the "empty_set" event in the show view

## Architecture impact

| Touchpoint                                | Impact                                                              |
| ----------------------------------------- | ------------------------------------------------------------------- |
| `MusicLibrary.RecordSets`                 | New public function `empty_record_set/1`                            |
| `MusicLibraryWeb.RecordSetLive.Index`     | New event handler + dropdown button                                 |
| `MusicLibraryWeb.RecordSetLive.Show`      | New event handler + dropdown button                                 |
| No schema changes needed                  | `RecordSetItem` already has `on_delete: :delete_all` via `has_many` |
| No PubSub / routes / external API changes | This is purely local                                                |

## Performance

The implementation uses a single `DELETE FROM record_set_items WHERE record_set_id = ?` query (bulk delete). No N+1 risk. The reload is a single `get_record_set!/1` call that preloads the (now empty) items list. This is the same pattern already used by `delete_record_set/1` (which relies on cascading deletes) and `remove_record_from_set/2` (which deletes one item and reloads).

## Documentation updates

- `docs/architecture.md` — no changes needed (no new modules, schemas, or subsystems)
- `docs/project-conventions.md` — no changes needed (follows existing patterns)
