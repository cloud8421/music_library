---
name: update-documentation
description: Use when the user asks to update project documentation, or after significant code changes that may have made docs/architecture.md, docs/project-conventions.md, docs/production-infrastructure.md, or any .agents/skills/*/SKILL.md file stale. Also trigger when new modules, schemas, workers, LiveViews, routes, external integrations have been added or removed, when queues or rate limits change, when testing conventions evolve, or when new commit rules are established.
---

# Update Documentation

Updates `docs/architecture.md`, `docs/project-conventions.md`, `docs/production-infrastructure.md`,
and all `.agents/skills/*/SKILL.md` files to reflect recent codebase changes.

## Guards

**CRITICAL: NEVER modify content within `usage_rules` generated blocks.** These blocks
are delimited by `<!-- usage-rules-skill-start -->` and `<!-- usage-rules-skill-end -->`.
The only skill currently containing such blocks is `ui-framework/SKILL.md`. When
editing any skill file, check for these markers first and treat the content between
them as read-only. If a proposed change would land inside a usage_rules block, skip
that change or restructure it to go outside the block.

## Workflow (Docs)

Steps 1–3 are independent per file — run them in parallel using subagents (one per
doc file) to speed up analysis. Merge the results before presenting to the user in
step 4.

### 1. Find the last documentation update

```bash
git log -1 --format="%H %as %s" -- docs/architecture.md
git log -1 --format="%H %as %s" -- docs/project-conventions.md
git log -1 --format="%H %as %s" -- docs/production-infrastructure.md
```

### 2. List all commits since then

```bash
git log --oneline <last-commit-hash>..HEAD
```

If there are no commits after the last update, the file is already up to date — skip it.

### 3. Analyze each commit for documentation impact

For each commit, check if it introduced changes relevant to the documentation file:

- **architecture.md**: new/removed/renamed modules, schemas, contexts, workers, routes, external integrations, supervision tree changes, database changes, PubSub topics, LiveView/LiveComponent additions
- **project-conventions.md**: new patterns established across 3+ commits, new conventions visible in code review, changed testing patterns, new error handling approaches, new UI/template conventions
- **production-infrastructure.md**: hosting/deployment changes, database configuration, backup strategy, environment variables, monitoring/observability, CI/CD pipeline, external service integrations, Docker/release configuration

Use `git show --stat <hash>` and `git show <hash>` to understand each commit.

**Skip these — they do not need documentation updates:**

- Bug fixes and minor tweaks that don't change structure
- Dependency version bumps (unless they change a major integration)
- Refactors that rename internals without changing the public API or module structure
- Test-only changes
- Skill or AGENTS.md changes

### 4. Prepare the update

- Read the current documentation file
- **Follow the existing format and section structure.** Each doc file has an established
  layout with specific tables, headings, and conventions. Add new entries to existing
  sections rather than inventing new structures. Match the style of surrounding content
  (e.g., if a table uses `| Module | Purpose |` columns, add rows in the same format).
- Draft the specific edits needed (additions, modifications, removals)
- Present the proposed changes to the user for review before applying them

### 5. Get human approval

Show the user:

- Which commits drove the changes
- What sections are being added, modified, or removed
- The exact content of each edit

Only apply changes after explicit approval.

### 6. Apply and verify (Docs)

- Apply the approved edits
- Commit with a message describing what was updated (e.g., "Update architecture docs" or "Update project conventions")

## Workflow (Skills)

Skills in `.agents/skills/*/SKILL.md` contain hardcoded reference tables and conventions
that must stay in sync with the codebase. When code changes render a skill stale, update it.

### Which Skills to Check After Code Changes

| Code Change                        | Skills to Check                                                                      |
| ---------------------------------- | ------------------------------------------------------------------------------------ |
| New/removed Oban worker            | `oban-worker/SKILL.md` — worker tables (On-Demand, Cron), queue assignments          |
| Queue configuration change         | `oban-worker/SKILL.md` — Queues table                                                |
| New/removed Oban plugin            | `oban-worker/SKILL.md` — Plugins table                                               |
| New/removed API integration        | `external-api-integration/SKILL.md` — Rate limit intervals, fixture modules list     |
| Rate limit interval change         | `external-api-integration/SKILL.md` — Intervals table, `architecture.md`             |
| New/removed API fixture module     | `external-api-integration/SKILL.md` — Available API Fixture Modules table            |
| New test fixture module            | `testing/SKILL.md` — Available fixture modules table                                 |
| New SQL pattern becomes convention | `sqlite-optimization/SKILL.md` — add to patterns/anti-patterns                       |
| New LiveView or LiveComponent      | `architecture.md` — LiveViews / LiveComponents tables                                |
| New/removed schema or context      | `architecture.md` — Schemas / Contexts tables                                        |
| New/renamed module (any)           | `architecture.md` — relevant section                                                 |
| Route changes                      | `architecture.md` — Router Structure                                                 |
| PubSub topic changes               | `architecture.md` — PubSub Topics table                                              |
| New/removed JS hook or event       | `architecture.md` — JS Hooks / JS Event Listeners tables                             |
| Testing convention change          | `testing/SKILL.md` — relevant section; `project-conventions.md`                      |
| Commit convention change           | `git-commit/SKILL.md` — relevant section; `project-conventions.md`                   |
| UI convention change               | `ui-framework/SKILL.md` — relevant section (outside usage_rules blocks)              |
| Production infra change            | `production-infrastructure.md`; `production-investigation/SKILL.md` if monitoring changes |
| Dependency category added/removed  | `update-dependencies/SKILL.md` — workflow steps                                      |
| Skill added or removed             | This file — update the table above                                                   |

### Skill Update Workflow

1. **Identify stale content.** After code changes, check the table above for affected skills.
   Read the skill file and compare its reference tables, patterns, and conventions against
   the current codebase.

2. **Check for usage_rules blocks.** Before editing any skill, read it and identify
   `<!-- usage-rules-skill-start -->` / `<!-- usage-rules-skill-end -->` markers.
   Content between them is auto-generated and MUST NOT be modified.

3. **Prepare changes.** Apply the same principles as doc updates:
   - Follow the existing section structure and formatting
   - Add entries to existing tables; don't invent new structures
   - Match the style of surrounding content

4. **Get human approval.** Present proposed skill changes alongside doc changes.

5. **Apply and commit.** Use a commit message describing what was updated
   (e.g., "Update oban-worker skill for new cron workers").
