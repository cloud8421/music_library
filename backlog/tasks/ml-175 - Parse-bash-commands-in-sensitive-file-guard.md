---
id: ML-175
title: Parse bash commands in sensitive file guard
status: To Do
assignee: []
created_date: "2026-05-10 06:29"
updated_date: "2026-05-11 06:46"
labels:
  - pi
  - ready
dependencies: []
references:
  - .pi/extensions/000-sensitive-file-guard.ts
  - .pi/sensitive-paths.json
documentation:
  - "https://github.com/webpro-nl/unbash#readme"
  - "https://www.npmjs.com/package/unbash"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Make `.pi/extensions/000-sensitive-file-guard.ts` more robust by parsing bash tool commands structurally using [unbash](https://github.com/webpro-nl/unbash) — a zero-dependency, TypeScript-native bash parser — instead of matching blocked command regexes against the entire command string. The current implementation treats bash input as plain text: blocked paths are detected by substring matching after stripping glob characters, and blocked commands such as `env` and `printenv` are regex-matched anywhere in the command. Since unbash is a pure JS/TS library with no native dependencies, it loads cleanly in pi's jiti extension runtime without compilation or WASM setup. The goal is to block actual command invocations and relevant nested shell execution contexts without false positives from quoted strings or comments.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Bash tool command blocking is based on parsed shell syntax rather than regex matching over the entire command string.
- [ ] #2 Actual invocations of configured blocked commands such as `env` and `printenv` are blocked when used as simple commands.
- [ ] #3 Blocked commands are also detected in nested shell syntax that can execute commands, including command substitutions and subshells.
- [ ] #4 Non-executed text such as quoted strings and comments does not trigger blocked command detection.
- [ ] #5 Existing sensitive path blocking behavior for non-bash tools remains unchanged.
- [ ] #6 The implementation degrades safely if bash parsing fails, either by blocking the command or falling back to the existing conservative text checks.
- [ ] #7 Focused tests or a documented local verification cover allowed and blocked bash examples, including false-positive and nested-command cases.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Implementation Plan

### 1. Objective alignment

The current guard treats bash tool calls as opaque strings, matching blocked command regexes (`printenv`, `\benv\b`) against the entire command text. This causes false positives from quoted strings, comments, and echo arguments — any text containing the blocked word triggers a block regardless of whether it would actually execute.

The proposed solution replaces whole-string regex scanning with structural parsing via `unbash`. After parsing the command into an AST, we walk the tree to collect only command names from executable positions (simple commands, subshell bodies, command substitution bodies, pipeline members). Blocked commands are then checked via exact set membership against collected names. Non-executed text (comments, quoted strings, echo arguments) is structurally excluded by the AST and never inspected.

This directly maps the problem (regex over plain text) to the solution (structural AST walk), satisfying AC #1-4.

### 2. Simplicity and alternatives considered

**Chosen approach: `unbash` (zero-dependency TypeScript bash parser)**

- Zero transitive dependencies → minimal supply-chain risk for a security guard
- Pure TypeScript, ESM-only → loads natively in pi's jiti runtime without native compilation or WASM setup
- Tolerant parsing — collects errors rather than throwing → natural degradation path (AC #6)
- 53KB minified / 13KB gzipped
- 16× faster than tree-sitter-bash WASM on short inputs

**Supply-chain hardening:** `unbash` is the sole new dependency and has zero transitive dependencies, which minimizes the attack surface. To further harden, the version is pinned to an exact version in `package.json` (e.g., `"unbash": "1.0.0"` — no `^` or `~` prefix). This prevents accidental upgrades via `npm update` or `npm install` on another machine. Any future version bump must be a deliberate, reviewed decision evaluating the diff between the pinned version and the candidate version.

**Alternatives evaluated and rejected:**

| Alternative                     | Why rejected                                                                                                                           |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `tree-sitter` (native bindings) | Requires node-gyp + C compiler toolchain; fragile across platforms; fails AC #6 if compilation breaks                                  |
| `web-tree-sitter` (WASM)        | Requires manual WASM file loading + path resolution; heavier (multi-MB); 16× slower than unbash                                        |
| `@banyudu/bash-parser` v0.6.0   | 17 transitive dependencies including `babylon` (JS parser) and `jison`; heavier than unbash                                            |
| `bash-parser` v0.5.0            | Abandoned since 2017, same 17-dep footprint                                                                                            |
| `shlep` v0.3.0                  | Abandoned since 2020; thin wrapper over `moo` tokenizer without full AST                                                               |
| Shell lexer (no deps)           | Would require hand-rolling comment/quote stripping + subshell detection; unbash covers all cases with a smaller, tested implementation |
| Keep current regex approach     | Does not satisfy any acceptance criteria — still has false positives from quoted strings/comments                                      |

### 3. Completeness and sequencing

**Step 1 — Convert to directory-style extension**

- Create `.pi/extensions/sensitive-file-guard/` directory
- Move `.pi/extensions/000-sensitive-file-guard.ts` → `.pi/extensions/sensitive-file-guard/index.ts`
- Create `.pi/extensions/sensitive-file-guard/package.json` with `unbash` pinned to an exact version under `dependencies` (no `^` or `~` prefix — use `"unbash": "1.0.0"` or the current latest)
- Run `npm install` in `.pi/extensions/sensitive-file-guard/`
- Delete `.pi/extensions/000-sensitive-file-guard.ts` to prevent double-loading (pi discovers extensions by scanning `.pi/extensions/`, so both the old file and new directory would register handlers)

→ _Dependency: none._  
→ _Verification: `pi` starts without errors; `/reload` works; `sensitive-file-guard` extension listed in RPC `list_extensions`._

**Step 2 — Implement AST walker helper**

Add a helper function (in `index.ts` or a sibling `ast.ts`) that:

- Calls `parse(command)` from `unbash`
- Recursively walks `Script.commands[]`, descending into `Subshell`, `CommandSubstitution`, `ProcessSubstitution`, `Pipeline`, `List`, `If.clause/then/else`, `While`, `For`, `Case` bodies
- Collects `.name.text` from all `SimpleCommand` nodes encountered, guarding against `undefined` (`.name` is absent for bare assignments like `FOO=bar` or for redirection-only commands)
- Returns `Set<string>` of command names (lowercased for case-insensitive matching)

**AST field verification before coding the walker:** `unbash`'s AST node type field names should be confirmed by running `console.log(JSON.stringify(parse("if true; then env; fi"), null, 2))` and inspecting the output. The npm page confirms `clause`/`then`/`else` for `If`, but other control-flow nodes should be spot-checked. This avoids misnamed field accesses that silently return nothing.

→ _Dependency: Step 1._  
→ _Verification: Unit test or manual `pi -e` run calling the helper with representative commands and asserting the returned command names._

**Step 3 — Wire into `tool_call` handler**

In the `bash` tool_call handler, replace:

```typescript
const cmdHit = commandRegexes.find((r) => r.test(command));
```

with:

```typescript
const parsedNames = extractCommandNames(command); // from Step 2 helper
const blocked = new Set(config.blocked_commands.map((c) => c.toLowerCase()));
const cmdHit = [...parsedNames].find((name) => blocked.has(name.toLowerCase()));
```

**Config format update:** The current `sensitive-paths.json` stores `blocked_commands` as regex patterns (`"\\benv\\b"`, `"printenv"`). The new `Set`-based matching requires plain command names. **Update `sensitive-paths.json`** to change `blocked_commands` from `["printenv", "\\benv\\b"]` to `["printenv", "env"]`.

Keep the existing regex fallback for degradation: if `extractCommandNames` throws or returns an empty set for a non-empty command, fall through to `commandRegexes.find(...)` to satisfy AC #6. The `commandRegexes` array remains built from `config.blocked_commands` as before for this fallback path.

→ _Dependency: Step 2._  
→ _Verification: `printenv` blocked; `echo printenv` allowed; `$(printenv)` blocked; `# printenv` allowed._

**Step 4 — Keep path-blocking unchanged**

No changes to the path-based tool blocking (read, write, edit, grep, find, ls) or the bash path-substring check. These continue using the existing logic.

→ _Dependency: none._  
→ _Verification: Existing path blocks still fire; non-bash tools unaffected._

**Step 5 — Verification run**

Test the full extension in `pi` with the following commands and verify each result:

| Command                    | Expected | Reason                                              |
| -------------------------- | -------- | --------------------------------------------------- |
| `printenv`                 | BLOCKED  | Simple command match                                |
| `env FOO=bar`              | BLOCKED  | Simple command match                                |
| `$(env)`                   | BLOCKED  | Command substitution                                |
| `$(printenv)`              | BLOCKED  | Command substitution                                |
| `(env)`                    | BLOCKED  | Subshell                                            |
| `` `env` ``                | BLOCKED  | Backtick command substitution                       |
| `env \| grep FOO`          | BLOCKED  | Pipeline — `env` is the first simple command        |
| `grep FOO \| env`          | BLOCKED  | Pipeline — `env` is the second simple command       |
| `for f in *; do env; done` | BLOCKED  | `env` in loop body                                  |
| `FOO=bar printenv`         | BLOCKED  | Assignment prefix — `printenv` is still the command |
| `echo printenv`            | ALLOWED  | `printenv` is an argument, not a command            |
| `# printenv`               | ALLOWED  | Comment                                             |
| `echo "use env to..."`     | ALLOWED  | Inside double-quoted string                         |
| `echo 'printenv'`          | ALLOWED  | Inside single-quoted string                         |
| `export FOO=bar`           | ALLOWED  | `export` is not in blocked_commands                 |
| `ls -la`                   | ALLOWED  | `ls` is not in blocked_commands                     |

→ _Dependency: Steps 1-4._  
→ _Verification: Run each command via `pi` bash tool and confirm block/allow matches table._

### 4. Verifiability

Each step above includes specific verification instructions. For the overall implementation:

- **Automated**: A standalone TypeScript test file (`extractCommandNames.test.ts`) inside the extension directory can import `extractCommandNames` and assert the returned `Set<string>` for representative inputs. Add `tsx` as a devDependency in the extension's `package.json` and run with `npx tsx extractCommandNames.test.ts`.
- **Manual**: Load the extension in `pi` and execute the verification table commands from Step 5, confirming each block/allow decision matches.
- **Regression guard**: The existing path-blocking regex tests are preserved by Step 4 — no changes to that code path.

### 5. Architecture impact analysis

**Touchpoints affected:**

| Touchpoint                                          | Impact                                                                                                                                                                         |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `.pi/extensions/000-sensitive-file-guard.ts`        | **Removed** — replaced by directory extension                                                                                                                                  |
| `.pi/extensions/sensitive-file-guard/index.ts`      | **New** — rewritten extension entry point                                                                                                                                      |
| `.pi/extensions/sensitive-file-guard/package.json`  | **New** — declares `unbash` dependency (exact version, pinned)                                                                                                                 |
| `.pi/extensions/sensitive-file-guard/node_modules/` | **New** — installed by `npm install`                                                                                                                                           |
| `.pi/sensitive-paths.json`                          | **Changed** — `blocked_commands` values updated from regex patterns (`"\\benv\\b"`) to plain command names (`"env"`); `_comment` field updated to document the expected format |
| `.pi/settings.json`                                 | **No change** — extension auto-discovered from `.pi/extensions/`                                                                                                               |
| All Elixir modules, schemas, contexts, DB           | **No impact** — pi extension change only                                                                                                                                       |
| PubSub, supervision tree, Oban, routes              | **No impact**                                                                                                                                                                  |
| External APIs, production infrastructure            | **No impact**                                                                                                                                                                  |

**Migration path**: Remove `.pi/extensions/000-sensitive-file-guard.ts` as the final action of Step 1. No other cleanup needed.

### 6. Performance profile

`unbash` parsing runs once per intercepted bash tool call. Benchmarks (Apple M1 Pro, Node.js v22):

- Short commands (e.g., `printenv`): ~0.1ms
- Medium commands (e.g., `for f in *.txt; do cat "$f"; done`): ~0.5ms
- Long scripts: ~2ms for 50-line scripts

The AST walk adds O(n) traversal over the parsed tree nodes, proportional to the AST size. For typical AI-generated bash commands (under 100 nodes), the total overhead is < 1ms per call — negligible compared to bash execution time and network latency.

**Memory**: The parsed AST is garbage-collected after each call. `unbash` is 53KB minified, loaded once at extension startup. No persistent parser state.

**No database impact, no N+1 risk, no I/O outside of the initial `npm install` (one-time).**

### 7. Benchmarking requirements

No ongoing benchmarks needed. The parser is called once per user-initiated bash tool call (low frequency, human-driven), not in a hot loop or request path.

**One-off validation**: During Step 5 verification, confirm that parsing latency is sub-millisecond for representative commands using `console.time` / `console.timeEnd` in the extension. If parsing exceeds 5ms for any command under 500 characters, investigate.

### 8. Cost profile

**Zero cost.** `unbash` is ISC-licensed, free, and has zero transitive dependencies. No API calls, no compute resources, no storage beyond the extension's `node_modules/` directory (~100KB on disk).

### 9. Production Changes

**None.** This change affects only the local pi extension runtime. No server-side configuration, environment variables, database migrations, DNS changes, or deployment steps are required. The extension runs in the developer's local pi process and does not touch production infrastructure.

### 10. Documentation updates

| File                                         | Change                                                                                                                                                                                                                             |
| -------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.pi/extensions/000-sensitive-file-guard.ts` | **Removed** — replaced by directory extension; new file has updated inline comments                                                                                                                                                |
| `.pi/sensitive-paths.json`                   | **Updated** — `blocked_commands` changed from regex patterns to plain command names; `_comment` field updated to document that `blocked_commands` entries are exact command names (not regexes) and are matched case-insensitively |
| `AGENTS.md` (Project Context section)        | **No change needed** — the sensitive file guard is already documented via the system prompt injection in `before_agent_start`; the list of blocked paths/commands is unchanged                                                     |
| `docs/architecture.md`                       | **No change** — pi extensions are not tracked in architecture.md (only Elixir app architecture)                                                                                                                                    |
| `docs/project-conventions.md`                | **No change** — no new conventions introduced                                                                                                                                                                                      |
| Task ML-175                                  | This plan serves as the implementation documentation                                                                                                                                                                               |

No README, API docs, or external documentation affected.

<!-- SECTION:PLAN:END -->
