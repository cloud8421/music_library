---
id: ML-148
title: Resilient chat infrastructure
status: To Do
assignee: []
created_date: '2026-04-27 09:04'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current chat infrastructure is poorly architected:

1. Implementation files mix plumbing (streaming, decoding) with domain specific parsing
2. Execution is directly in the component, which ends up blocking interaction
3. No formal state machine
4. Difficult to test in isolation
5. Usage of opaque function callbacks to customize behaviour, which is a JavaScript pattern more than a idiomatic elixir one

Proposed new architecture:

1. Dynamic supervisor, which starts/resumes chats keyed by their ID
2. Stream process handles fetching, loading and storing messages.
3. Stream process provides pub-sub primitives with domain specific events which do not expose internals.
4. Component uses higher level API, reducing boilerplate.
<!-- SECTION:DESCRIPTION:END -->
