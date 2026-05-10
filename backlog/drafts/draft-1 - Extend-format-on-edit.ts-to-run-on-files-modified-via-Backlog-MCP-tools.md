---
id: DRAFT-1
title: Extend format-on-edit.ts to run on files modified via Backlog MCP tools
status: Draft
assignee: []
created_date: '2026-05-10 06:59'
labels:
  - pi-extension
  - tooling
  - backlog
dependencies: []
references:
  - .pi/extensions/format-on-edit.ts
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The pi extension `.pi/extensions/format-on-edit.ts` currently formats files (Elixir via `mix format`, markdown via `prettier`) only when the `edit` or `write` tools are used. When Backlog MCP tools (`backlog_task_edit`, `backlog_document_create`, etc.) modify files under `backlog/`, no formatting is triggered.

The `tool_result` event fires for the `mcp` tool with `event.input.tool` set to the Backlog tool name, so it's technically possible to hook into these calls. The main challenge is mapping MCP tool calls to the specific files that were modified.
<!-- SECTION:DESCRIPTION:END -->
