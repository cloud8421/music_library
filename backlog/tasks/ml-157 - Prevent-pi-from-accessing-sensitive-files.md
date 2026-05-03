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

Content: JSON object with `blocked_paths` (glob-like patterns for path matching) and `blocked_commands` (regex patterns for bash command scanning of commands that leak secrets without a path in the string, e.g., `printenv`, `env`, `set`).

The config includes a `_comment` field (ignored by the extension) to document each pattern's purpose, since JSON does not support inline comments.

Example config:

```json
{
  "_comment": "Patterns for blocking sensitive file access by pi. Glob-like for paths, regex for commands.",
  "blocked_paths": [
    ".env",
    ".envrc",
    "*.pem",
    "*.key",
    "*.key.pub",
    "*secret*",
    "*credential*",
    "*credentials*",
    ".ssh/",
    ".aws/",
    ".gnupg/",
    "~/.pi/agent/sessions/"
  ],
  "blocked_commands": [
    "printenv",
    "\\benv\\b",
    "\\bset\\b"
  ]
}
```

Initial patterns cover:
- `.env` files: `.env`, `.envrc` (`.env.*` is NOT included — it would false-positive on `.env.example`, which must remain readable)
- Key files: `*.pem`, `*.key`, `*.key.pub`
- Secret/credential files: paths containing `secret`, `credential`, `credentials`
- Sensitive directories: `.ssh/`, `.aws/`, `.gnupg/`
- Pi session files (contain tool outputs): `~/.pi/agent/sessions/`
- Bash commands that dump environment: `printenv`, `env`, `set` (match as whole words via `\b` anchors)

**`.env.example` exclusion:** The pattern `.env.*` is deliberately omitted from `blocked_paths` so `.env.example` is not caught. If a `.env.production` file exists and should be blocked, add the specific pattern `.env.production` rather than the wildcard `.env.*`.

Verification: File exists at `.pi/sensitive-paths.json` and is valid JSON.

**Step 2: Create the extension**

File: `.pi/extensions/sensitive-file-guard.ts`

Implementation:
1. Read `.pi/sensitive-paths.json` at extension load time (synchronous, using `readFileSync`)
2. Compile `blocked_paths` entries into a regex matcher (glob → regex conversion, all patterns compiled with the case-insensitive `i` flag to handle case-insensitive filesystems like macOS):
   - `*` → `.*`
   - `.` → `\.` (escape literal dots)
   - `/` → `\/` (escape path separators)
   - Wrap in anchors: `^` and `$` for exact patterns, or allow partial match for glob-like patterns
   - Apply `i` flag for case-insensitive matching
3. Subscribe to `tool_call` event
4. Handler logic:
   - **Path-based tools** (`read`, `grep`, `write`, `edit`, `find`, `ls`):
     a. Resolve `event.input.path` to an absolute path using `path.resolve(ctx.cwd, event.input.path)`, then normalize with `path.normalize()` to collapse `..` segments. This defends against path traversal (`../.env`, `../../.env`).
     b. Check the resolved absolute path against the compiled blocked path regexes.
   - **Bash tool**: Two separate checks with distinct purposes:
     a. **Blocked path scan:** Search the raw `event.input.command` string for fragments that match blocked path patterns (e.g., `.env`, `.ssh/`, `.aws/`). This catches commands like `cat .env`, `grep foo ~/.ssh/config`, `cat /absolute/path/.env`. The scan is a simple substring/regex match against the command text — it does not parse shell syntax. This covers the most common accidental access patterns.
     b. **Blocked command check:** Test `event.input.command` against `blocked_commands` regexes (from config). These cover commands that leak secrets *without* a path argument in the command string (e.g., `printenv`, `env`, `set`, `export`). Each regex uses `\b` word-boundary anchors to avoid false positives (e.g., `env` should match `env` but not `environment`).
   - **Blocking and notification:**
     - If match found and `ctx.hasUI` is true: show a warning notification via `ctx.ui.notify()`
     - If match found: return `{ block: true, reason: "Blocked sensitive path: <path or command>" }` (error message for non-interactive mode)
     - If no match: return `undefined` (allow execution)

**Edge Cases and Accepted Limitations:**

| Scenario | Handling | Rationale |
|----------|----------|-----------|
| `cat ".env"` (quoted) | Caught by path substring scan | Quotes don't hide the path fragment |
| `cat ./.env` (relative with `./`) | Caught by path substring scan | `.env` fragment still present |
| `cat /absolute/path/.env` | Caught by path substring scan | `.env` fragment still present |
| `cat $HOME/project/.env` | Caught (if `.env` appears verbatim) | Variable expansion at start doesn't mask the path fragment |
| `head .env`, `tail .env`, `less .env` | Caught by path substring scan | All contain `.env` fragment |
| `echo $MY_SECRET` (no file access) | NOT caught | This reads from environment memory, not disk. PI would need separate treatment for this (out of scope) |
| `cat $(echo .env)` (command substitution) | NOT caught | Requires shell parsing; accepted limitation for accidental-access use case |
| `eval 'cat .env'` | NOT caught | Requires shell parsing; accepted limitation |
| `sh -c 'cat .env'` | Caught by path substring scan | `.env` appears in the command string |
| Case variants (`.ENV`, `.Env`) | Caught by case-insensitive regex (`i` flag) | macOS filesystems are case-insensitive |
| Path traversal (`../.env`) | Caught by `path.resolve` + `path.normalize` | Resolved absolute path contains `.env` fragment |
| Symlinks (`config -> ~/.aws/`) | NOT caught in initial implementation | Resolving symlinks requires I/O (`realpathSync`) per tool call. Documented limitation; users must not symlink sensitive directories into the project tree. Can be added later via a config option `followSymlinks: true` |
| `/etc/passwd` (system file) | NOT caught unless pattern added to config | Config is the source of truth for blocked paths; system files are not blocked by default |

**Bash scanning scope:** The bash scanner uses simple substring/regex matching on the raw command string. It is designed to catch *accidental* access by the LLM, not adversarial bypass by a human. Commands using shell variable expansion, command substitution, or indirect execution may evade detection; this is an accepted limitation documented above.

Verification:
- Start pi in this project, ask it to read `.env.example` (should work — this is NOT a secret, it's the example)
- Ask pi to read `.env` (should be blocked with a notification)
- Ask pi to run `cat .env` via bash (should be blocked)
- Ask pi to run `cat ../.env` via bash (should be blocked — path traversal)
- Ask pi to run `ls .` (should work — listing the project root is fine)
- Run `pi -p "read .env"` (non-interactive mode — should report error)
- Run `pi -p "read lib/music_library.ex"` (non-interactive mode — should succeed with normal output)

**Step 2.5: Write automated path-matching tests**

File: `.pi/extensions/sensitive-file-guard.test.ts`

Extract the path-matching logic into a pure function (`isBlockedPath(resolvedPath, blockedPatterns)` and `isBlockedCommand(command, blockedCommands)`) that takes config as input with no side effects (no filesystem I/O, no pi API calls). Write a table-driven test suite that asserts expected block/allow outcomes:

```typescript
// Example test table structure
const pathTests = [
  // [description, resolvedPath, expectedBlocked]
  [".env file", "/project/.env", true],
  [".env.example file", "/project/.env.example", false],
  ["nested .env", "/project/config/.env", true],
  ["normal source file", "/project/lib/music_library.ex", false],
  ["SSH config", "/Users/me/.ssh/config", true],
  ["AWS credentials", "/Users/me/.aws/credentials", true],
  [".env with case variant", "/project/.ENV", true],
  [".Env mixed case", "/project/.Env", true],
  ["secret in filename", "/project/config/secrets.yml", true],
  ["credential in path", "/project/config/credentials.json", true],
  [".pem key file", "/project/keys/server.pem", true],
  [".key file", "/project/keys/private.key", true],
];

const commandTests = [
  // [description, command, expectedBlocked]
  ["cat .env", "cat .env", true],
  ["cat ./.env", "cat ./.env", true],
  ["grep in .ssh", "grep -r foo ~/.ssh/", true],
  ["cat lib/music_library.ex", "cat lib/music_library.ex", false],
  ["printenv", "printenv", true],
  ["env command", "env", true],
  ["mix test (safe)", "mix test", false],
  ["echo .env (mentioning, not accessing)", "echo .env", true],
  ["environment variable ref (false positive)", "echo $NODE_ENV", false],
];
```

Run with: `node --import tsx .pi/extensions/sensitive-file-guard.test.ts`

This guarantees path-matching correctness independently of pi's runtime, catches regressions when patterns are updated, and documents expected behavior for each edge case.

Verification: All tests pass before proceeding to integration verification.

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
| Read .env via path traversal | read | `../.env` | Blocked |
| Read .env.production | read | `.env.production` | Blocked (if pattern added) |
| Read .env.example | read | `.env.example` | **Allowed** (example file) |
| Read .ENV (case variant) | read | `.ENV` | Blocked (case-insensitive) |
| Read secrets file | read | `config/secrets.yml` | Blocked |
| Cat .env via bash | bash | `cat .env` | Blocked |
| Cat .env via bash with quotes | bash | `cat ".env"` | Blocked |
| Cat ./.env via bash | bash | `cat ./.env` | Blocked |
| Grep in .ssh | grep | `~/.ssh/config` | Blocked |
| Ls in .aws | ls | `~/.aws/` | Blocked |
| Write to .env | write | `.env` | Blocked |
| Edit .env | edit | `.env` | Blocked |
| Bash printenv (no path) | bash | `printenv` | Blocked |
| Bash env command | bash | `env` | Blocked |
| Bash echo $NODE_ENV (false positive check) | bash | `echo $NODE_ENV` | **Allowed** (`\b` anchor) |
| Read normal .ex file | read | `lib/music_library.ex` | Allowed |
| Run mix test | bash | `mix test` | Allowed |
| Non-interactive read .env | read | `.env` (print mode) | Error reported |
| Non-interactive read source file | read | `lib/music_library.ex` (print mode) | Normal output |
| Add pattern + /reload | read | newly blocked path | Blocked after reload |

### 5. Architecture Impact Analysis

| Touchpoint | Impact |
|------------|--------|
| `.pi/extensions/sensitive-file-guard.ts` | **New file** — extension entry point. Named `000-sensitive-file-guard.ts` (or similar numeric prefix) to ensure it loads **first** among project-local extensions. Since `tool_call` handlers chain in load order and later handlers can mutate `event.input` before this guard sees it, loading first guarantees the guard inspects the original, unmodified tool arguments. |
| `.pi/sensitive-paths.json` | **New file** — declarative blocked patterns config |
| `tool_call` event | New subscriber, chains with existing extensions (e.g., MCP adapter). The guard runs **before** the MCP adapter's `tool_call` handler, so sensitive file access is blocked before any MCP forwarding occurs. |
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
- The `_comment` field convention for documenting patterns inline
- The behavior in interactive vs. non-interactive modes
- How to temporarily disable (comment out patterns, or start pi with `--no-extensions`)
- Accepted limitations (no symlink resolution, no shell parsing for command substitution)

**`.pi/extensions/sensitive-file-guard.test.ts`** — Already included as Step 2.5. This file serves as living documentation of expected behavior for each edge case.

**`docs/available-tasks.md`** — Add a note that `mise run pi` loads the sensitive file guard, so pi commands through mise are protected.

**SKILL.md (optional)** — Consider creating `.claude/skills/sensitive-file-guard/SKILL.md` so pi itself understands the guard's behavior. Without this, pi may try to read a blocked file, receive the block reason in the next turn, and need to re-plan. A SKILL.md pre-loads this knowledge so pi avoids attempting blocked paths proactively. This is a nice-to-have, not required for the initial implementation.

**No other documentation files need updates.** This is a pi-level concern, not an application architecture concern.
<!-- SECTION:PLAN:END -->
