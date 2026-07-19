---
id: ML-232
title: Harden and streamline the Pi harness
status: To Do
assignee: []
created_date: "2026-07-19 06:11"
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
