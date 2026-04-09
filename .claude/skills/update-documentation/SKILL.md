---
name: update-documentation
description: Use when the user asks to update project documentation, or after significant code changes that may have made docs/architecture.md, docs/project-conventions.md, or docs/production-infrastructure.md stale. Also trigger when new modules, schemas, workers, LiveViews, routes, or external integrations have been added or removed.
---

# Update Documentation

Updates `docs/architecture.md`, `docs/project-conventions.md`, and `docs/production-infrastructure.md` to reflect recent codebase changes.

## Workflow

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
- Skill or CLAUDE.md changes

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

### 6. Apply and verify

- Apply the approved edits
- Commit with a message describing what was updated (e.g., "Update architecture docs" or "Update project conventions")
