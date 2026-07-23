---
id: ML-232
title: Harden and streamline the Pi harness
status: To Do
assignee: []
created_date: "2026-07-19 06:11"
updated_date: "2026-07-23 08:47"
labels:
  - pi
  - harness
  - security
dependencies: []
references:
  - "https://github.com/lopopolo/harness-engineering"
  - >-
    https://github.com/lopopolo/harness-engineering/blob/trunk/playbooks/repository-review.md
  - AGENTS.md
  - docs/architecture.md
  - docs/project-conventions.md
  - docs/production-infrastructure.md
priority: high
type: enhancement
ordinal: 63000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

A harness-engineering review of the repository at revision 8e69603209fbf45972176611da16631aa7e9358f found that the Pi setup already has strong foundations: AGENTS.md routes work into architecture and conventions, project skills provide progressive disclosure, extensions expose CI/browser/runtime/production observability, and executable checks encode many settled requirements.

The next improvement should consolidate and harden this existing harness rather than add more undifferentiated instructions or tools.

Findings, in consequence order:

1. Production authority is enforced primarily through prose. The prod-errors extension exposes mute, unmute, resolve, and reopen mutations without an extension-level approval gate. Production credentials are available to the Pi process, while sensitive-file-guard fails open on invalid configuration and only intercepts selected built-in tool names. Its claim to block all tool access is stronger than its implementation.

2. The worker epoch is not reproducible from the repository. Pi is not pinned in mise.toml, pi-mcp-adapter is installed from an unversioned package reference with an ignored lockfile, chrome-devtools-mcp runs at latest, and extensions use both the legacy Mario Zechner and current Earendil Works import namespaces.

3. Harness proof misses high-consequence surfaces. The local dev:pi-test task passes 159 tests, but the Pi Extensions workflow duplicates only part of that task and omits prod-metrics. Prod-errors and prod-logs have no test suites. Guard tests cover command parsing rather than extension-level access control. Production tools return isError fields even though the current Pi contract requires throwing to mark tool failure, and format-on-edit silently ignores formatter failures.

4. Progressive disclosure exists but baseline context is unnecessarily large. Tidewave and the complete Chrome DevTools server are exposed as direct MCP tools, production and CI tools are always active, and the mandatory architecture document is approximately 60 KB. Broad skill trigger descriptions can activate multiple large skills for loosely related work.

5. Duplicated semantic owners have already drifted. RepoVacuum is configured for 03:03 and documented that way in the Oban skill, while architecture.md says 03:00. The query-reporter skill names an obsolete Tidewave tool, the documentation skill requires an unavailable subagent capability, and pre-commit documentation overstates the checks that scripts/dev/precommit actually runs.

Apply the harness-engineering principles of explicit authority, a fixed and qualified worker epoch, just-in-time context, legible tools, one authoritative owner per fact, and claim-matched proof. Preserve the existing root routing model, domain skills, bounded tool output, real-system observability, pinned GitHub Actions, deployment approval, and post-deploy verification.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Production mutation tools require a mechanically enforced, auditable approval grant and reject unauthorized or non-interactive mutation attempts.
- [ ] #2 Production read and mutation credentials have documented, least-privilege scopes and are not ambiently available beyond the tools that require them.
- [ ] #3 The sensitive-file guard behavior and documentation agree, fail-open behavior is removed or explicitly accepted, and tests cover the complete enforced boundary rather than only shell command parsing.
- [ ] #4 The qualified Pi worker epoch is reproducible from a clean checkout, including pinned Pi, MCP adapter, browser MCP, and extension dependency versions, with one supported Pi package namespace.
- [ ] #5 One repository-owned Pi verification command is used locally and in CI and covers every tested extension, including production logs, errors, metrics, mutation behavior, error signaling, and guard integration.
- [ ] #6 Custom Pi tool failures use the current Pi error contract and formatter failures are surfaced with an actionable diagnostic.
- [ ] #7 The default active tool and context set is reduced through direct-tool selection or lazy discovery while representative coding, UI, production investigation, and CI journeys remain discoverable and operable.
- [ ] #8 Volatile schedules, tool names, and verification claims have one authoritative owner or a mechanical consistency check, and the known RepoVacuum, QueryReporter, documentation-skill, and pre-commit drift is corrected.
- [ ] #9 Harness documentation records the supported worker configuration, authority boundaries, verification command, representative smoke journeys, and known exclusions.
- [ ] #10 A clean-checkout harness smoke test and the complete Pi extension test suite pass in CI.

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Delivery strategy

Execute ML-232 through the seven focused subtasks below. The split keeps security authority, guard enforcement, reproducibility, verification, tool/context performance, and final documentation independently reviewable while making their dependencies explicit.

### Wave 1: independent foundations

1. **ML-232.1 — Gate Pi production mutations and scope credentials.** Delivers parent AC #1-#2. It owns the only manual production rollout and rollback section.
2. **ML-232.2 — Harden the sensitive-file guard boundary.** Delivers parent AC #3 and documents the extension-versus-OS security boundary.
3. **ML-232.3 — Pin and qualify the Pi worker epoch.** Delivers parent AC #4 and establishes the versions used by all later verification.

These can be implemented in parallel, but each must pass its focused tests before the shared verification task begins.

### Wave 2: proof and tool exposure

4. **ML-232.4 — Unify Pi extension verification and error signaling.** Depends on ML-232.1-.3 and delivers parent AC #5-#6. It makes `mise run dev:pi-test` the local/CI verification owner and covers the security behavior from Wave 1.
5. **ML-232.5 — Make optional Pi and MCP tools lazy.** Depends on ML-232.3 and delivers the tool half of parent AC #7, including the required before/after schema benchmark and representative discovery journeys.

### Wave 3: context disclosure

6. **ML-232.6 — Split Pi harness context for progressive disclosure.** Depends on ML-232.5 and delivers the context half of parent AC #7. It keeps the required architecture-first route while moving detailed references behind focused links and measuring context reduction.

### Wave 4: ownership, documentation, and clean proof

7. **ML-232.7 — Remove harness drift and document clean-checkout operation.** Depends on ML-232.4 and ML-232.6 and delivers parent AC #8-#10. It corrects the four known drift cases, creates the operational harness guide, adds clean-checkout CI smoke, and maps every parent criterion to evidence.

## Simplicity and alternatives

Prefer existing Pi primitives: TUI confirmation and session entries for authority, `tool_call` and `user_bash` interception for the guard, mise/npm locks for reproducibility, `pi.setActiveTools` for lazy tools, and the MCP adapter proxy for MCP discovery. Do not add a new production service, database, generalized documentation generator, or OS sandbox in this task. Those alternatives are materially larger and are documented as exclusions where relevant.

## Verification and completion order

Each child plan contains focused commands and objective evidence. ML-232.4 must prove the complete extension suite through one command. ML-232.5 and ML-232.6 must record one-off tool/context measurements. ML-232.7 must run the locked clean-checkout smoke in CI with no secrets or live external calls. Do not check a parent criterion until its child task is finalized under the Backlog finalization guide and the evidence matrix points to passing output or an explicitly approved manual production verification.

## Architecture, performance, and cost profile

Only ML-232.1 changes Phoenix API authentication/routing and production runtime configuration; it does not change schemas or databases. The remaining work changes local harness tooling, CI, and documentation ownership. Runtime complexity remains bounded and local. Required benchmarks are limited to tool-schema/context size and clean/warm harness timings; no application benchmark is needed. No new paid service is introduced. Lazy discovery may add one model round trip on first use but is expected to save thousands of repeated input tokens per turn; tests and CI must make no model, production, Coolify, or other paid API calls.

## Production changes

All manual production work is isolated in ML-232.1: provision scoped tokens, configure on-demand local credential lookup, verify cross-scope denial, rotate the Coolify log token if supported, then revoke obsolete broad Pi credentials. These steps require explicit user approval and include rollback. No other subtask may interact with production.

## Documentation ownership

ML-232.7 creates/finalizes `docs/pi-harness.md` as the supported worker/authority/verification guide. ML-232.1 updates production infrastructure and production-investigation guidance. ML-232.6 restructures architecture references and skill triggers. ML-232.7 corrects QueryReporter, documentation-skill, schedule, and pre-commit drift, then links volatile facts to their executable owners rather than copying them.
<!-- SECTION:PLAN:END -->
