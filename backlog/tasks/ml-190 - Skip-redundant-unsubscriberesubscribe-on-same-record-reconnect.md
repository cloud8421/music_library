---
id: ML-190
title: Skip redundant unsubscribe+resubscribe on same-record reconnect
status: To Do
assignee: []
created_date: "2026-05-19 08:42"
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
