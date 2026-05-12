---
id: ML-174
title: Add menu action to empty a set
status: To Do
assignee: []
created_date: "2026-05-09 17:57"
updated_date: "2026-05-11 06:45"
labels:
  - ready
dependencies: []
references:
  - backlog/docs/doc-16 - Research-Add-menu-action-to-empty-a-set.md
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

For record sets, it would be useful to empty the set, which means removing all items in the set in one single operation. The action should be available in the dropdown menu already available in each set (both in the index and show views).

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Clicking "Empty" in the set dropdown (index view) removes all records from that set and the card updates to show 0/0 records
- [ ] #2 Clicking "Empty" in the set dropdown (show view) removes all records and the grid clears
- [ ] #3 A confirmation prompt appears before emptying the set
- [ ] #4 Emptying a set does not delete the set itself (name, description, and metadata are preserved)
- [ ] #5 The context function `RecordSets.empty_record_set/1` returns `{:ok, record_set}` with an empty items list
  <!-- AC:END -->
  <!-- SECTION:PLAN:BEGIN -->

## Implementation Plan

### 1. Add `empty_record_set/1` to `MusicLibrary.RecordSets`

Add a new public function that bulk-deletes all `RecordSetItem` rows for a given set in a single query, then reloads the set.

**File:** `lib/music_library/record_sets.ex`

```elixir
@spec empty_record_set(RecordSet.t()) :: {:ok, RecordSet.t()}
def empty_record_set(%RecordSet{} = record_set) do
  from(i in RecordSetItem, where: i.record_set_id == ^record_set.id)
  |> Repo.delete_all()

  {:ok, get_record_set!(record_set.id)}
end
```

**Rationale:** `Repo.delete_all` issues a single `DELETE FROM record_set_items WHERE record_set_id = ?` — no N+1 regardless of item count. Only the `id` field is needed from the struct. Not wrapped in a transaction — consistent with `remove_record_from_set/2` and `reorder_records_in_set/2`.

### 2. Add "Empty" button and handler to index view

**File:** `lib/music_library_web/live/record_set_live/index.ex`

Add a `dropdown_button` **below the separator**, grouped with "Delete" (since emptying is a destructive action). Place it between the separator and the existing "Delete" button:

```heex
<.dropdown_separator />
<.dropdown_button
  phx-click="empty_set"
  phx-value-id={@record_set.id}
  data-confirm={gettext("Remove all records from this set?")}
>
  {gettext("Empty")}
</.dropdown_button>
<.dropdown_button
  phx-click="delete_set"
  ...
>
  {gettext("Delete")}
</.dropdown_button>
```

Add `handle_event`. Pass only the ID via a minimal struct to avoid a redundant `get_record_set!` call (the function itself does the reload):

```elixir
def handle_event("empty_set", %{"id" => id}, socket) do
  {:ok, updated_set} = RecordSets.empty_record_set(%RecordSet{id: id})
  {:noreply, update_record_set_in_list(socket, updated_set)}
end
```

### 3. Add "Empty" button and handler to show view

**File:** `lib/music_library_web/live/record_set_live/show.ex`

Add the same `dropdown_button` **below the separator**, before "Delete" (same placement as index). Add `handle_event` with a success toast for consistency with `delete_set`:

```elixir
def handle_event("empty_set", _params, socket) do
  {:ok, updated_set} = RecordSets.empty_record_set(socket.assigns.record_set)
  {:noreply,
   socket
   |> assign(:record_set, updated_set)
   |> put_toast(:info, gettext("Set emptied"))}
end
```

### 4. Add tests

**File:** `test/music_library/record_sets_test.exs`

Add a new `describe "empty_record_set/1"` block with two tests:

```elixir
describe "empty_record_set/1" do
  test "removes all items and returns the empty set" do
    {set, [_r1, _r2, r3]} = record_set_with_records(3)

    {:ok, updated} = RecordSets.empty_record_set(set)
    assert updated.items == []
    # Set metadata preserved
    assert updated.name == set.name
    assert updated.description == set.description
    # Items are actually deleted from DB
    assert [] =
             from(i in RecordSetItem, where: i.record_set_id == ^set.id)
             |> Repo.all()
  end

  test "is a no-op on already-empty sets" do
    set = record_set()
    assert set.items == []

    {:ok, updated} = RecordSets.empty_record_set(set)
    assert updated.items == []
  end
end
```

**No LiveView tests are planned.** The project does not currently have LiveView test files for `RecordSetLive.Index` or `RecordSetLive.Show`. UI acceptance criteria (#1–#4 from the acceptance criteria list) will be verified manually using the steps below. The context-level tests above cover acceptance criterion #5.

### Verification

| Step                            | Verification                                                                                                                     |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| 1. Context function             | Run `mix test test/music_library/record_sets_test.exs` — both tests pass                                                         |
| 2. Edge case: already-empty set | Run `mix test test/music_library/record_sets_test.exs:NNN` (line of the no-op test)                                              |
| 3. Index UI                     | Manual: open record sets index, click dropdown → Empty, confirm prompt appears, confirm → card updates to show 0/0 records       |
| 4. Show UI                      | Manual: open a set show page, click dropdown → Empty, confirm prompt appears, confirm → grid clears, toast "Set emptied" appears |
| 5. Set preserved                | After emptying, verify set name and description are still visible on both index card and show page                               |
| 6. Full test suite              | Run `mix test` — all existing tests still pass                                                                                   |

<!-- SECTION:PLAN:END -->

## Definition of Done

<!-- DOD:BEGIN -->

- [ ] #1 `RecordSets.empty_record_set/1` added and tested
- [ ] #2 "Empty" dropdown button present in both index and show views
- [ ] #3 Confirmation prompt shown before emptying
- [ ] #4 Set metadata preserved after emptying
- [ ] #5 All existing tests still pass
<!-- DOD:END -->
