---
description: Work on an existing backlog task end-to-end
argument-hint: "<TASK-ID>"
---

We're going to work on task $1 end-to-end. Follow the Backlog.md Task Execution workflow
step by step, ensuring every step is completed before moving to the next.

## Pre-flight

Before touching any code:

1. **Read the project documentation.** Open and read `docs/architecture.md` and
   `docs/project-conventions.md`.

2. **Load the task plan.** Use `backlog_task_view` to load task $1 and read its
   implementation plan, acceptance criteria, and notes. Do not proceed until you
   understand the plan.

3. **Load relevant skills based on the task's domain upfront.**. When undecided
   if a skill is relevant or not, opt for loading it anyway.

## Execution

Follow the Backlog.md Task Execution workflow:

1. **Mark the task In Progress** and assign yourself via `backlog_task_edit`.
2. **Present the plan to the user** — summarize the approach and ask for
   confirmation before writing any code. Wait for explicit approval.
3. **Work in short loops:** implement a step, run the relevant tests, and
   immediately check off acceptance criteria with `backlog_task_edit`
   (`acceptanceCriteriaCheck` field) when they are met. If you catch yourself
   running in circles, stop and let the user know.
4. **Log progress** with `backlog_task_edit` (`notesAppend` field) to document
   decisions, blockers, or learnings.
5. **If the plan needs to change**, update it first via `backlog_task_edit`
   (`planSet` or `planAppend`), get confirmation, then continue.
6. **If new work appears outside the original acceptance criteria**, STOP and
   ask the user before expanding scope. Never silently add AC or create
   follow-up tasks.

## Done vs Complete

When implementation is finished, do NOT call `backlog_task_complete` or
`backlog_task_archive`. Those move the task to the archive — they are for
periodic batch cleanup, not for marking work finished.

Instead, follow the Task Finalization workflow:

1. **Verify all acceptance criteria** are checked (use `backlog_task_view` to
   review).
2. **Verify all Definition of Done items** are checked.
3. **Confirm tests pass** — run the full test suite or the relevant test files
   and verify no new warnings or regressions.
4. **Write the Final Summary** via `backlog_task_edit` (`finalSummary` field).
   Include what changed, why, tests run, and any risks or follow-ups.
5. **Update the plan** if the executed approach deviated from what was recorded.
6. **Set status to "Done"** via `backlog_task_edit`.

Only then is the task truly done.

## After Finalization

- **Never autonomously create or start new tasks.**
- If follow-up work is needed, present the idea to the user and ask.
- If this was a subtask and the user instructed you to work on a parent "and all
  subtasks," proceed to the next subtask. Otherwise, ask the user whether to
  continue.
