---
id: ML-190
title: Skip redundant unsubscribe+resubscribe on same-record reconnect
status: To Do
assignee: []
created_date: "2026-05-19 08:42"
updated_date: "2026-05-19 09:26"
labels:
  - audit
  - pubsub
  - optimization
dependencies: []
documentation:
  - >-
    audits/phase2-pubsub-lifecycle/doc-25 -
    Audit-Report-PubSub-Subscription-Lifecycle-Phase-2.md
modified_files:
  - lib/music_library_web/live_helpers/record_actions.ex
priority: low
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

`RecordActions.manage_subscription/2` unsubscribes the old record and subscribes the new record on every `handle_params` call. When LiveView reconnects to the same record (e.g., after a WebSocket drop within the reconnect grace period), it unsubscribes and resubscribes to the same topic. While harmless (Phoenix.PubSub deduplicates by PID), a same-record check would be a micro-optimization.

**Fix:** Add a guard: `if socket.assigns[:record] && socket.assigns.record.id != new_id, do: Records.unsubscribe(...)` — only unsubscribe when the record actually changes.

**Source:** Audit doc-25 (Phase 2), Recommendation #2.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 manage_subscription/2 only calls unsubscribe when old record ID differs from new ID
- [ ] #2 Same-record reconnect skips unsubscribe+resubscribe entirely
- [ ] #3 All existing tests pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Overview

Micro-optimization to skip the redundant `Records.unsubscribe/1` call when a LiveView reconnects to the same record. The change is a single guard addition in `RecordActions.manage_subscription/2`. No other modules are affected.

**Nature:** Code hygiene, not a measurable performance win. The skip eliminates at most two ETS operations on reconnect, which Phoenix.PubSub already deduplicates by PID internally.

## Callers (no changes needed)

| LiveView            | File                                                 | Line | Hook              |
| ------------------- | ---------------------------------------------------- | ---- | ----------------- |
| CollectionLive.Show | `lib/music_library_web/live/collection_live/show.ex` | 361  | `handle_params/3` |
| WishlistLive.Show   | `lib/music_library_web/live/wishlist_live/show.ex`   | 298  | `handle_params/3` |

Both call `manage_subscription(socket, id)` at the top of `handle_params/3` before loading the record. No caller changes are needed because the function signature and return value (`:ok`) remain unchanged.

## Code change

**File:** `lib/music_library_web/live_helpers/record_actions.ex`

Change the unsubscribe guard from:

```elixir
if socket.assigns[:record], do: Records.unsubscribe(socket.assigns.record.id)
```

to:

```elixir
if socket.assigns[:record] && socket.assigns.record.id != new_id,
  do: Records.unsubscribe(socket.assigns.record.id)
```

The `Records.subscribe(new_id)` call is intentionally left unconditional: on same-record reconnect it's a no-op (PubSub deduplicates by PID), and on first mount it's required.

## Edge-case coverage

| Scenario                     | `socket.assigns[:record]` | old vs new     | Unsub? | Sub?        | Correct? |
| ---------------------------- | ------------------------- | -------------- | ------ | ----------- | -------- |
| First mount                  | `nil`                     | short-circuits | No     | Yes         | ✅       |
| Navigate to different record | record A                  | A ≠ B          | Yes    | Yes         | ✅       |
| Reconnect same record        | record X                  | X == X         | No     | Yes (no-op) | ✅       |

## Verification steps

1. **Run existing tests:**

   ```bash
   mix test test/music_library_web/live_helpers/record_actions_test.exs
   mix test test/music_library_web/live/collection_live/show_test.exs
   mix test test/music_library_web/live/wishlist_live/show_test.exs
   ```

   All should pass. These cover `manage_subscription/2` indirectly through PubSub broadcast handling and full page navigation tests.

2. **Manual reconnect smoke test (optional):** Navigate to a record show page, kill the server, restart it, and confirm the page reconnects and continues to receive PubSub updates (e.g., trigger a background cover refresh and verify the toast appears).

3. **No new test is strictly required.** The change is a pure optimization — it removes a redundant call that was already harmless. Existing PubSub broadcast tests in `record_actions_test.exs` (the `handle_record_updated` describe block) confirm the subscription lifecycle works end-to-end.

## Documentation

- No user-facing docs need updating.
- The `@doc` for `manage_subscription/2` is already accurate and does not need amendment.
- No production infrastructure changes, environment variables, or migrations are required.
<!-- SECTION:PLAN:END -->
