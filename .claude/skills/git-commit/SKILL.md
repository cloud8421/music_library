---
name: git-commit
description: Use this skill when committing code, writing commit messages, staging changes, or preparing to push. Use PROACTIVELY when the user mentions "commit", "git commit", "commit message", "push", "stage", "what should I commit", or when code changes are complete and ready to be committed. Also use when the user asks about commit conventions or style.
---

# Git Commit Conventions

Project-specific commit message rules and workflow. These conventions are enforced
and commits that don't follow them will be rejected.

## Checklist Before Committing

1. **Is there a Backlog task?** If the work maps to a task, the task ID MUST prefix
   the commit subject.

2. **Is the subject under 60 characters?** Including the task ID prefix.

3. **Is this a single logical change?** One change per commit. If a change spans
   multiple tasks, split the commit.

4. **Did you run precommit checks?** `mise run dev:precommit` before committing.

## Commit Message Format

```
<task-id-prefix>: <imperative present tense summary, ≤60 chars>

<optional body with details, wrapped at 72 chars>

<version table for dependency updates>
```

### Subject Line Rules

- **Imperative present tense**: "Add scrobble rule validation" NOT "Added..." or "Adds..."
- **Describe intent/behavior**, not implementation details: "Fix record ordering on search page" NOT "Change ORDER BY clause in list_records"
- **Single-line, under 60 characters**
- **Task ID prefix when applicable**: `ML-3: fix scrobble rule ordering`
- The prefix counts toward the 60-char limit

### Examples

```
# With Backlog task
ML-3: fix scrobble rule ordering

# Without task (trivial fixes)
Fix typo in artist biography template

# Dependency updates
Update dependencies

mix:
  bandit 1.6.10 => 1.6.11
  phoenix_live_view 1.1.0 => 1.1.1

# NPM dependency updates
Update npm dependencies

npm:
  tailwindcss 4.1.4 => 4.1.5
  sortablejs 1.15.3 => 1.15.6

# Revert
Revert "ML-3: fix scrobble rule ordering"
```

### Dependency Update Format

The subject is **always** "Update dependencies" (Mix) or "Update npm dependencies" (npm).
Never use "bump" or "upgrade" in the subject.

The body MUST list each specific version change as `package_name from => to`:

```
mix:
  bandit 1.6.10 => 1.6.11
  phoenix_live_view 1.1.0 => 1.1.1
```

### What NOT to Include

- ❌ "Co-Authored-By" references in the message body
- ❌ Multi-line subjects
- ❌ Past tense ("Added", "Fixed")
- ❌ Implementation details ("Changed the SQL query")
- ❌ "bump" or "upgrade" for dependency updates
- ❌ Multiple unrelated changes in one commit

## Workflow

### Before Committing

```bash
# Run precommit checks
mise run dev:precommit
```

This runs: format check, gettext check, credo, sobelow, mix_audit, shellcheck,
Docker image validation, and asset build.

### Staging

Stage specific files, not `git add .`:

```bash
git add lib/music_library/records.ex test/music_library/records_test.exs
```

### Commit Message Validation

After writing the commit message, verify:
1. Subject is imperative present tense
2. Subject is ≤60 characters (including task ID)
3. Task ID references the correct Backlog task
4. Body describes what changed (if non-trivial)

### Backlog Task Integration

- **One task ID per commit subject.** If work spans tasks, split the commit.
- **Read the task's implementation plan** before committing to verify the plan
  was followed.
- **When finalizing a task**, the commit should be the last logical change
  for that task.

## Prohibited

- **Never create, comment on, close, or reopen GitHub issues** — only the user does that. Use Backlog.md for task management.
- **Never reference GitHub issue numbers** in commit messages. Use Backlog task IDs.
- **Never use `{:discard, reason}`** — use `{:cancel, reason}` in Oban workers (related but common in commits).
