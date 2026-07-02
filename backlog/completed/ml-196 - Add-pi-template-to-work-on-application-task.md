---
id: ML-196
title: Add pi template to work on application task
status: Done
assignee: []
created_date: "2026-05-22 09:40"
updated_date: "2026-05-22 14:12"
labels: []
dependencies: []
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

- Solicit reading architecture
- Solicit loading relevant skills
- Make sure it'd done, and not complete

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Template file exists at .pi/prompts/application-task.md with correct frontmatter (description + argument-hint)
- [x] #2 Template instructs agent to read docs/architecture.md and docs/project-conventions.md before writing code without summarizing their contents
- [x] #3 Template instructs agent to load relevant skills based on their descriptions and triggers, without hardcoding a domain→skill mapping
- [x] #4 Template distinguishes Done status from task_complete/task_archive per Backlog.md finalization workflow
- [x] #5 Template covers the full Backlog.md execution workflow: pre-flight → present plan → work loops → finalization → after finalization

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

Create `.pi/prompts/application-task.md` that:

1. **Solicits architecture reading** — instructs the agent to read `docs/architecture.md` and `docs/project-conventions.md` before touching code
2. **Solicits loading relevant skills** — maps task domains (database, UI, testing, workers, APIs, etc.) to their corresponding `.agents/skills/*/SKILL.md` files and instructs the agent to load all relevant ones
3. **Distinguishes done from complete** — follows the Backlog.md Task Finalization workflow: verify AC, verify DoD, run tests, write Final Summary, set status to "Done". Explicitly warns against calling `task_complete` or `task_archive` for marking work finished.
4. **Follows Backlog.md execution workflow** — mark In Progress, present plan, work in short loops, log progress, handle scope changes, finalize properly

The template uses `argument-hint: "<TASK-ID>"` for autocomplete compatibility with the `/application-task <ID>` invocation pattern.

Updated pre-flight after review: point 1 no longer summarizes doc contents, point 3 no longer hardcodes a domain→skill mapping — instead instructs agent to load skills based on their own descriptions and triggers.

<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Created `.pi/prompts/application-task.md` — a pi prompt template for working on Backlog.md tasks end-to-end.

**What it does:**

- **Pre-flight phase**: instructs the agent to read `docs/architecture.md` and `docs/project-conventions.md` before writing code, load the task plan from Backlog.md, and identify + read all relevant `.agents/skills/` files based on the task's domain (database, UI, testing, workers, APIs, etc.)
- **Execution phase**: follows the Backlog.md Task Execution workflow — mark In Progress, present plan for approval, work in short loops, log progress, handle scope changes
- **Done vs Complete distinction**: explicitly warns against `task_complete`/`task_archive` and follows the Backlog.md Task Finalization workflow (verify AC, verify DoD, run tests, write Final Summary, set status to "Done")
- **After finalization**: reminders about not autonomously creating tasks and proper subtask handoff

**Template**: invocable as `/application-task <TASK-ID>` via pi's prompt template system.

<!-- SECTION:FINAL_SUMMARY:END -->
