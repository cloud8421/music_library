---
id: doc-2
title: Prevent pi from accessing sensitive files
type: other
created_date: '2026-05-03 13:32'
updated_date: '2026-05-04 06:55'
---
# Implementation Analysis: Prevent pi from accessing sensitive files

## Summary

The task requires a **declarative** way to intercept pi tool calls that would access sensitive files (e.g., `.env`, secrets, credentials, API keys). Pi's extension system provides the `tool_call` event hook, which fires **before** any tool executes and supports blocking.

## Sensitive File Categories (for this project)

| Category | Patterns | Examples |
|----------|----------|----------|
| Environment secrets | `.env`, `.env.*`, `.envrc` | `.env`, `.env.production` |
| Key files | `*.pem`, `*.key`, `*.key.pub` | SSH keys |
| Secret/credential files | `*secret*`, `*credential*`, `*credentials*` | `secrets.yml`, `credentials.json` |
| Config dirs | `.ssh/`, `.aws/`, `.gnupg/` | SSH config, AWS credentials |
| Production config | Any path known to contain secrets | `rel/`, production env vars |
| Pi session files | `~/.pi/agent/sessions/` | Session JSONL files (contain tool outputs) |

## Available Pi Extension Mechanisms

### `tool_call` event (primary approach)

The `tool_call` event fires after `tool_execution_start` and **before** the tool executes. It can block execution:

```typescript
pi.on("tool_call", async (event, ctx) => {
  if (event.toolName === "read" && isSensitivePath(event.input.path)) {
    return { block: true, reason: "Sensitive file blocked" };
  }
});
```

**Key capabilities:**
- `event.toolName` — identifies the tool (`read`, `bash`, `grep`, `find`, `ls`, `write`, `edit`)
- `event.input` — tool parameters (mutable, can be patched)
- `isToolCallEventType("read", event)` — type-narrows for specific tools
- Return `{ block: true, reason: "..." }` to prevent execution
- `ctx.hasUI` — check if interactive (for notifications)
- `ctx.ui.notify(...)` — show warning in UI

### Tools that can access sensitive files

| Tool | Danger | Input fields to check |
|------|--------|----------------------|
| `read` | **High** — reads file content into LLM context | `input.path` |
| `bash` | **High** — can `cat`, `grep`, `curl` any file | `input.command` (regex match) |
| `grep` | **High** — searches file contents | `input.path` |
| `find` | **Low** — lists filenames only | `input.path` (directory listing) |
| `ls` | **Low** — lists directory contents | `input.path` |
| `write` | **Medium** — could overwrite sensitive files | `input.path` |
| `edit` | **Medium** — could modify sensitive files | `input.path` |

### `tool_result` event (secondary approach)

Fires **after** execution. Can modify results but NOT block. Useful for sanitization, but harder to get right:

```typescript
pi.on("tool_result", async (event, ctx) => {
  // Modify event.content or event.details
  return { content: [...], details: {...} };
});
```

### Full tool override (heavyweight approach)

Register a replacement for `read`/`bash` with the same name. Requires reimplementing built-in functionality:

```typescript
pi.registerTool({
  name: "read",
  // ... must implement full read logic
});
```

## Implementation Routes

### Route A: `tool_call` event interception (RECOMMENDED)

**Description:** Single extension listening on `tool_call`, checking paths/commands against a configuration file of protected patterns. Blocks matching calls.

**Implementation:**
1. Create `.pi/extensions/sensitive-file-guard.ts` (or `index.ts` in a directory)
2. Create `.pi/sensitive-paths.json` — declarative config listing protected patterns
3. In `tool_call` handler:
   - For `read`, `grep`, `write`, `edit`: check `input.path` against patterns
   - For `bash`: regex-scan `input.command` for sensitive paths
   - For `find`, `ls`: check directory paths
   - Block if match, notify in UI

**Sample config file (`.pi/sensitive-paths.json`):**
```json
{
  "blocked_paths": [
    ".env",
    ".env.*",
    "*.pem",
    "*.key",
    "*secret*",
    "*credential*",
    "*credentials*",
    ".ssh/",
    ".aws/",
    ".gnupg/",
    "config/*.secret.exs"
  ],
  "blocked_commands": [
    "cat .env",
    "cat ~/.ssh",
    "printenv",
    "cat ~/.aws"
  ]
}
```

**Pros:**
- Minimal code (~60 lines of TypeScript)
- Declarative configuration file (easy to audit and update)
- Works with ALL tools (read, bash, grep, find, ls, write, edit)
- No reimplementation of built-in tools
- Inherits built-in rendering (syntax highlighting, diffs, etc.)
- Easy to extend with new patterns
- Fails safe (blocks before any file access)

**Cons:**
- Can't sanitize partial output (but blocking prevents all access)
- Regex-based command scanning for bash has edge cases
- `find`/`ls` only blocked at directory level, not per-file

**Code size estimate:** ~80 lines TypeScript + ~20 lines JSON config

---

### Route B: Full tool override (read + bash)

**Description:** Override the `read` and `bash` tools with custom implementations that include path checking. Delegates to original implementation for allowed paths.

**Implementation:**
1. Create `.pi/extensions/sensitive-file-guard/` directory
2. Override `read` tool: check paths, delegate allowed reads to original implementation
3. Override `bash` tool: scan commands, delegate allowed commands to original implementation
4. Optionally override `grep`, `find`, `ls`, `write`, `edit`

**Pros:**
- Full control (can log, can sanitize output, can modify behavior)
- No event overhead per tool call
- Can add audit logging

**Cons:**
- Must reimplement or re-wrap built-in tool logic (~200+ lines)
- Must maintain compatibility with pi updates
- More complex testing
- Risk of subtle behavior differences vs built-in
- Lose or must reimplement built-in rendering

**Code size estimate:** ~300+ lines TypeScript

---

### Route C: Hybrid — `tool_call` + `tool_result` + config file

**Description:** Route A plus `tool_result` sanitization for cases where partial access is allowed.

**Implementation:**
Same as Route A, plus a `tool_result` handler that scans output for sensitive patterns and redacts them.

**Pros:**
- Most comprehensive protection
- Can allow partial access with sanitization

**Cons:**
- Most complex
- `tool_result` sanitization is error-prone (false positives/negatives)
- Redacted content still consumes context tokens
- Hard to get right for all output formats

**Code size estimate:** ~150 lines TypeScript

---

## Recommendation: Route A

Route A (pure `tool_call` event interception with declarative config) is the **simplest viable approach** that meets all requirements:

1. **Declarative** ✓ — JSON config file lists protected patterns
2. **Comprehensive** ✓ — Covers all tools that can access files
3. **Simple** ✓ — ~80 lines of code, easy to review and maintain
4. **Safe** ✓ — Blocks BEFORE any file access, cannot fail open
5. **Minimal** ✓ — No reimplementation needed, no dependency on pi internals

## Architectural Impact

| Touchpoint | Impact |
|------------|--------|
| `.pi/extensions/` | New extension file added |
| `.pi/sensitive-paths.json` | New config file (declarative rules) |
| `tool_call` event | New subscriber, no breaking changes |
| Built-in tools | Unchanged (event interception is non-invasive) |
| `ctx.ui` | Used for notification only (no blocking dependency) |
| Other extensions | Compatible — tool_call handlers chain in load order |

## Open Questions

1. **Config format:** JSON vs YAML? JSON is simpler (no dependencies), YAML is more readable.
2. **Per-project vs global:** Should this be project-local (`.pi/`) or global (`~/.pi/agent/`)?
3. **Command scanning depth:** For bash, how aggressively should we scan? Regex on the command string has edge cases (e.g., `cat $HOME/.env`).
4. **Logging:** Should blocked attempts be logged for audit?
5. **Non-interactive mode:** Should sensitive access be blocked silently or with error in print/JSON modes?
