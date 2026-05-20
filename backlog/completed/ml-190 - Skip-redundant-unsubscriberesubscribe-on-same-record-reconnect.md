---
id: ML-190
title: Skip redundant unsubscribe+resubscribe on same-record reconnect
status: Done
assignee:
  - Codex
created_date: "2026-05-19 08:42"
updated_date: "2026-05-19 11:06"
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
  - test/music_library_web/live_helpers/record_actions_test.exs
priority: low
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

`RecordActions.manage_subscription/2` manages record show PubSub topics from `handle_params/3`. Phoenix.PubSub allows duplicate subscriptions for the same PID/topic and delivers duplicate events, so same-record parameter handling must leave the existing subscription untouched instead of subscribing again.

**Fix:** Make `manage_subscription/2` distinguish first subscription, different-record navigation, and same-record no-op. First mount subscribes to the record topic; navigating to a different record unsubscribes the old topic and subscribes the new topic; same-record handling does nothing.

**Source:** Audit doc-25 (Phase 2), Recommendation #2, corrected after verifying Phoenix.PubSub duplicate-subscription behavior.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 manage_subscription/2 leaves the existing PubSub subscription untouched when the assigned record ID already matches the new ID
- [x] #2 manage_subscription/2 still unsubscribes from the old record and subscribes to the new record when navigating between different records
- [x] #3 A regression test verifies same-record parameter handling does not create duplicate PubSub deliveries
- [x] #4 Relevant tests pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Overview

Correct the same-record subscription optimization so it avoids both sides of the redundant PubSub lifecycle. Phoenix.PubSub allows duplicate subscriptions for the same PID/topic and will deliver duplicate events, so same-record handling must not call `Records.subscribe/1` again.

## Implementation

1. Update `lib/music_library_web/live_helpers/record_actions.ex` so `manage_subscription/2` has explicit branches for first subscription, different-record navigation, and same-record no-op.
2. Add focused regression tests in `test/music_library_web/live_helpers/record_actions_test.exs` using a connected `Phoenix.LiveView.Socket` and the real `Records.subscribe/1` / `Records.notify_update/1` PubSub path.
3. Verify the same-record case delivers one broadcast once, and the different-record case stops receiving the old topic while receiving the new topic.
4. Run the focused helper/show tests and format the changed files.
5. Update this Backlog task to replace the previous incorrect PubSub deduplication note with the verified behavior.

## Documentation

No project architecture, production infrastructure, or convention docs need codebase-level changes because this is a bug fix within the existing `LiveHelpers.RecordActions.manage_subscription/2` pattern. The necessary documentation updates are the local `@doc` for `manage_subscription/2` and this task record, since it previously claimed Phoenix.PubSub deduplicates duplicate subscriptions.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Found that Phoenix.PubSub duplicate subscriptions are allowed and produce duplicate deliveries; the previous task notes/final summary claiming PID/topic deduplication were incorrect.

Updated `manage_subscription/2` to treat same-record handling as a no-op, preserving first-subscribe and different-record switch behavior. Added regression tests that prove one broadcast is delivered once after same-record handling and that different-record navigation drops the old topic.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Updated `RecordActions.manage_subscription/2` so it no-ops when the assigned record ID already matches the requested record ID. This prevents duplicate Phoenix.PubSub subscriptions, which would otherwise deliver duplicate `{:update, record}` messages for one broadcast.

The helper now has explicit branches for first subscription, different-record navigation, and same-record no-op. Its `@doc` was corrected to describe the actual behavior.

Added focused regression coverage in `test/music_library_web/live_helpers/record_actions_test.exs`:

- same-record subscription handling does not duplicate PubSub deliveries
- navigating between records unsubscribes the old topic and subscribes the new topic

Documentation update: corrected this Backlog task's description, plan, notes, and final summary. No project architecture, production infrastructure, or convention docs required changes because the behavior remains within the existing LiveView subscription pattern.

Tests run:
`mix test test/music_library_web/live_helpers/record_actions_test.exs test/music_library_web/live/collection_live/show_test.exs test/music_library_web/live/wishlist_live/show_test.exs` -> 23 passed

<!-- SECTION:FINAL_SUMMARY:END -->
