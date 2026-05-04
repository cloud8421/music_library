---
id: ML-60
title: Unify genre tag styling between edit and display
status: Done
assignee: []
created_date: "2026-04-20 08:54"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/115"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-16 · updated 2026-03-16 · closed 2026-03-16_

## Problem

Genre tags render differently in edit vs read contexts:

- **Read view** (`record_components.ex:650-652`): Uses `.badge variant="soft"` (Fluxon component)
- **Edit form** (`record_form.ex:75-93`): Uses custom inline spans with `bg-zinc-100 dark:bg-zinc-700 px-2 py-1 text-sm` and a remove button

## Decision needed

Should the edit form use `.badge variant="soft"` with an appended remove button to match the read view? Or is the visual difference acceptable since the edit form needs the remove interaction?

<!-- SECTION:DESCRIPTION:END -->
