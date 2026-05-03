---
id: ML-157
title: Prevent pi from accessing sensitive files
status: To Do
assignee: []
created_date: '2026-05-03 13:30'
updated_date: '2026-05-03 13:44'
labels: []
dependencies: []
references:
  - 'backlog://document/doc-2'
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
To prevent the pi harness from accidentally reading and sending sensitive data to the LLM, we need a declarative way to intercept problematic commands that interact with sensitive files that for example contain secrets.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pi cannot read `.env` files via the `read` tool — access is blocked with a notification in interactive mode
- [ ] #2 Pi cannot read files matching `*secret*` or `*credential*` patterns via the `read` tool
- [ ] #3 Pi cannot `cat .env` or `grep` inside `.ssh/` or `.aws/` via the `bash` tool
- [ ] #4 Non-interactive mode (`pi -p`) reports blocked sensitive file access as an error rather than silently failing
- [ ] #5 Normal file access (source code, test files, config examples like `.env.example`) is unaffected
- [ ] #6 The set of blocked paths is declared in `.pi/sensitive-paths.json` — adding/removing patterns does not require code changes
- [ ] #7 The extension loads correctly at pi startup and chains with existing extensions (MCP adapter) without conflicts
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### 1. Objective Alignment

The problem: pi's `read`, `bash`, `grep`, `find`, `ls`, `write`, and `edit` tools can access any file on disk, including secrets (`.env`, API keys, SSH keys, credentials). When a file is read, its content is sent to the LLM provider, potentially leaking secrets to a third party.

The solution: a pi extension that intercepts `tool_call` events before execution, checks the target paths against a declarative JSON config of blocked patterns, and blocks the call if it matches. This prevents any file content from reaching the LLM — the block happens before the tool executes, so no data is ever read from disk.

### 2. Simplicity and Alternatives Considered

**Chosen: Route A — `tool_call` event interception with JSON config**

This is the simplest viable approach:
- ~80 lines of TypeScript + a JSON config file
- Uses pi's built-in `tool_call` event hook (no tool reimplementation)
- Inherits built-in rendering and behavior for all tools
- Fail-safe: blocks BEFORE file access, cannot leak data

**Rejected alternatives:**

- **Route B (full tool override):** Requires reimplementing `read`, `bash`, `grep`, etc. (~300+ lines). Must maintain compatibility with pi's internal tool interfaces. Risk of subtle behavior differences. Overkill for a blocking gate.

- **Route C (tool_call + tool_result sanitization):** `tool_result` sanitization is error-prone — redacting secrets from arbitrary output is the same class of problem as sanitizing LLM output. Blocking upfront is safer and simpler.

- **Filesystem permissions (e.g., `chmod`):** Would break the application itself (Phoenix needs to read `.env`). Only pi needs to be restricted, not all processes.

- **`.gitignore`-based approach:** `.gitignore` controls what's tracked, not what's read. Many sensitive files are intentionally tracked (`.env.example`) or excluded from git for size (not sensitivity).

### 3. Completeness and Sequencing

**Step 1: Create blocked paths configuration**

File: `.pi/sensitive-paths.json`

Content: JSON object with `blocked_paths` (glob-like patterns for path matching) and `blocked_command_patterns` (regex patterns for bash command scanning).

Initial patterns cover:
- `.env` files: `.env`, `.env.*`, `.envrc`
- Key files: `*.pem`, `*.key`, `*.key.pub`
- Secret/credential files: paths containing `secret`, `credential`, `credentials`
- Sensitive directories: `.ssh/`, `.aws/`, `.gnupg/`
- Pi session files (contain tool outputs): `~/.pi/agent/sessions/`

Verification: File exists at `.pi/sensitive-paths.json` and is valid JSON.

**Step 2: Create the extension**

File: `.pi/extensions/sensitive-file-guard.ts`

Implementation:
1. Read `.pi/sensitive-paths.json` at extension load time (synchronous, using `readFileSync`)
2. Compile `blocked_paths` entries into a regex matcher (glob → regex conversion)
3. Subscribe to `tool_call` event
4. Handler logic:
   - For `read`, `grep`, `write`, `edit`, `find`, `ls`: check `event.input.path` against the compiled blocked path regexes. Resolve relative paths against `ctx.cwd`.
   - For `bash`: check `event.input.command` against `blocked_command_patterns` regexes AND scan for blocked paths in the command string
   - If match found and `ctx.hasUI` is true: show a warning notification via `ctx.ui.notify()`
   - If match found: return `{ block: true, reason: "Blocked sensitive path: <path>" }` (error message for non-interactive mode)
   - If no match: return `undefined` (allow execution)

Verification:
- Start pi in this project, ask it to read `.env.example` (should work — this is NOT a secret, it's the example)
- Ask pi to read `.env` (should be blocked with a notification)
- Ask pi to run `cat .env` via bash (should be blocked)
- Ask pi to run `ls .` (should work — listing the project root is fine)
- Run `pi -p "read .env"` (non-interactive mode — should report error)

**Step 3: Verify non-interactive mode behavior**

The extension must handle `ctx.hasUI === false` (print mode, JSON mode) by returning a descriptive error reason string, so the blocked access is reported to stdout rather than silently swallowed.

Verification:
```bash
pi -p "read the .env file" 2>&1 | grep -i "blocked"
# Should produce output indicating the access was blocked
```

**Step 4: Verify other tools are unaffected**

Ask pi to:
- Read a normal source file (e.g., `lib/music_library.ex`)
- Edit a normal file
- Run `mix test`
- Search with grep for normal code patterns

All should work as usual.

Verification: All normal pi operations are unaffected.

### 4. Verifiability

Each step includes concrete verification instructions above. Overall verification suite:

| Test Case | Tool | Target | Expected |
|-----------|------|--------|----------|
| Read .env | read | `.env` | Blocked |
| Read .env.production | read | `.env.production` | Blocked |
| Read .env.example | read | `.env.example` | **Allowed** (example file) |
| Read secrets file | read | `config/secrets.yml` | Blocked |
| Cat .env via bash | bash | `cat .env` | Blocked |
| Grep in .ssh | grep | `~/.ssh/config` | Blocked |
| Ls in .aws | ls | `~/.aws/` | Blocked |
| Write to .env | write | `.env` | Blocked |
| Edit .env | edit | `.env` | Blocked |
| Read normal .ex file | read | `lib/music_library.ex` | Allowed |
| Run mix test | bash | `mix test` | Allowed |
| Non-interactive read .env | read | `.env` (print mode) | Error reported |

### 5. Architecture Impact Analysis

| Touchpoint | Impact |
|------------|--------|
| `.pi/extensions/sensitive-file-guard.ts` | **New file** — extension entry point |
| `.pi/sensitive-paths.json` | **New file** — declarative blocked patterns config |
| `tool_call` event | New subscriber, chains with existing extensions (e.g., MCP adapter) |
| Built-in tools | **Unchanged** — interception is non-invasive |
| Phoenix/Ecto/Oban | **No impact** — pi-only concern, not part of the Elixir application |
| Production infrastructure | **No impact** — this is developer-local tooling, not server configuration |
| Other pi extensions (MCP adapter) | Compatible — `tool_call` handlers chain in load order. The guard runs alongside, not instead of. |

**No migration or deprecation path needed** — this is a net-new capability.

**Rollback:** Delete `.pi/extensions/sensitive-file-guard.ts` and `.pi/sensitive-paths.json` to remove all protections. No cleanup needed.

### 6. Performance Profile

- **Runtime complexity:** `O(p + c)` where `p` is number of blocked path patterns (~15) and `c` is number of blocked command patterns (~5). Each check is a single regex test. Total per tool call: <1ms.
- **Memory footprint:** Patterns are compiled once at extension load time. Regex objects and config: ~5KB.
- **Database queries:** None. This is a filesystem-level guard.
- **N+1 risks:** None. No database interaction.
- **Latency:** Negligible. The guard adds <1ms to each tool call, imperceptible next to tool execution time (often 100ms+ for file I/O).

### 7. Benchmarking Requirements

**No benchmarks needed.** The guard is a simple gate with constant-time pattern matching:
- O(20) regex tests per tool call
- No I/O beyond the initial config read (done once at startup)
- No allocations beyond the return value object
- Performance profile is self-evident from the code structure

If future patterns grow to hundreds of entries, a trie-based matcher could be considered, but the current scale (~15 patterns) does not warrant it.

### 8. Cost Profile

**Zero cost.** The guard:
- Uses no third-party APIs
- Consumes no paid resources
- Runs entirely locally in the pi process
- No additional compute, storage, or services required

### 9. Production Infrastructure Steps

**No production changes required.** This change:

- Is **developer-local tooling** (pi configuration files in `.pi/`)
- Does not affect the Elixir application, Phoenix server, database, or any deployed infrastructure
- Is not deployed to production servers
- Does not require environment variables, service provisioning, DNS changes, or firewall rules

**Rollout:** Each developer places the extension and config in their local `.pi/` directory. No server-side deployment.

**Rollback:** Remove the two files locally. No server-side action needed.

### 10. Documentation Updates

**`docs/project-conventions.md`** — Add a section "Pi Security Configuration" documenting:
- The existence of the sensitive file guard extension
- The location and format of `.pi/sensitive-paths.json`
- How to add or remove blocked patterns
- The behavior in interactive vs. non-interactive modes
- How to temporarily disable (comment out patterns, or start pi with `--no-extensions`)

**No other documentation files need updates.** This is a pi-level concern, not an application architecture concern.
<!-- SECTION:PLAN:END -->
