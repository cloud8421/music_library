---
id: ML-159
title: Replicate CI pipeline on tangled.org
status: Done
assignee: []
created_date: '2026-05-03 16:54'
updated_date: '2026-05-03 19:46'
labels: []
dependencies: []
documentation:
  - 'doc-4 - CI Pipeline Porting Analysis: GitHub Actions → Tangled Spindles'
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port the entire GitHub CI pipeline (lint, test, deploy) to tangled.org. The current pipeline includes: linting (format, gettext, credo, sobelow, mix_audit, shellcheck, Docker image validation, asset build), testing (partitioned tests with coverage ≥75%), deployment (Coolify API trigger via hurl, health check, post-deploy verification), dependency submission reporting, and a manual verification workflow. The goal is to replicate this functionality on tangled.org as the CI provider.
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Cancelled. Two reasons:
1. **Dev/CI parity loss** — moving from mise (used in both local dev and GitHub Actions) to Nix-based tooling would create a divergence between how developers install tools and how CI does. Mise reads `mise.toml` directly; Spindle would require either mise-as-nixpkgs-dep (adding download latency) or custom Nix derivations (adding maintenance burden).
2. **No build artifact caching** — Spindle has no `actions/cache` equivalent. `mix deps`, `_build`, `node_modules`, and asset builds would recompile from scratch every run. With Elixir 1.20.0-rc.4 not in nixpkgs, even the toolchain download is uncached. Cold runs estimate 10-20 min vs ~5 min cached on GitHub Actions.

Future direction: evaluate Buildkite (free solo tier, can wire production server as runner) or similar provider that supports caching and keeps mise-based tooling.
<!-- SECTION:FINAL_SUMMARY:END -->
