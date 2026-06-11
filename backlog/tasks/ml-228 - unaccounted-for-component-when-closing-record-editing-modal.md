---
id: ML-228
title: unaccounted for component when closing record editing modal
status: To Do
assignee: []
created_date: "2026-06-11 05:43"
labels:
  - bug
  - liveview
dependencies: []
priority: medium
ordinal: 61000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

When closing the record editing modal, this log line appears in the console:

```
[info] Component %Phoenix.LiveComponent.CID{cid: 5} not found in state for pid #PID<0.19829.0>
```

This indicates a LiveComponent is still sending messages (or being referenced) after it has been removed from the parent LiveView's state. The component lifecycle isn't being handled correctly when the modal is dismissed.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Closing the record editing modal does not produce any "Component not found in state" log messages
- [ ] #2 The modal continues to open, edit, and close correctly without visual or functional regressions
<!-- AC:END -->
