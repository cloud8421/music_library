---
name: update-documentation
description: Use when the user asks to update project documentation, or after significant code changes that may have made docs/architecture.md or docs/project-conventions.md stale
---

# Update Documentation

Updates `docs/architecture.md` and `docs/project-conventions.md` to reflect recent codebase changes.

## Workflow

For each documentation file (`docs/architecture.md`, `docs/project-conventions.md`):

### 1. Find the last documentation update

```bash
git log -1 --format="%H %as %s" -- docs/architecture.md
git log -1 --format="%H %as %s" -- docs/project-conventions.md
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

Use `git show --stat <hash>` and `git show <hash>` to understand each commit. Focus on structural changes, not bug fixes or minor tweaks.

### 4. Prepare the update

- Read the current documentation file
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
