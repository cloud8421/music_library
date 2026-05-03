---
id: doc-4
title: 'CI Pipeline Porting Analysis: GitHub Actions → Tangled Spindles'
type: other
created_date: '2026-05-03 16:57'
updated_date: '2026-05-03 17:07'
---
# CI Pipeline Porting Analysis: GitHub Actions → Tangled Spindles

## Current State (GitHub Actions)

Three workflows in `.github/workflows/`:

1. **`test_and_deploy.yml`** — 3 jobs: `lint` (parallel) + `test` (parallel) → `deploy` (sequential, main only, requires environment approval)
2. **`verify.yml`** — Manual workflow, re-runs production verification (hurl)
3. **`dependency_submission.yml`** — Reports Mix dependencies to GitHub dependency graph

Key GHA features used: `jdx/mise-action`, `actions/cache`, concurrency control, environment approvals, Fluxon private Hex repo.

## Tangled's CI Capabilities (Spindles)

Tangled provides **Spindles** — a CI runner service. Workflows are YAML files in `.tangled/workflows/`.

**Available features:**
- Triggers: `push`, `pull_request`, `manual` — with branch/tag glob filtering
- Engine: `nixery` (uses Nixpkgs packages via Nixery at `nixery.tangled.sh`)
- Dependencies: declared from nixpkgs (or custom registries)
- Environment: global and per-step env vars
- Steps: sequential only, each runs a Bash command in a fresh Docker container
- Secrets: repository-level, stored in OpenBao (or SQLite for self-hosted)
- Auto env vars: `CI`, `TANGLED_REF`, `TANGLED_SHA`, `TANGLED_REF_NAME`, etc.
- Clone: depth, submodules configurable
- Volumes persisted across steps within a run: `/tangled/workspace`, `/nix`
- Timeout: configurable via `SPINDLE_PIPELINES_WORKFLOW_TIMEOUT` (default 5m)

**Missing features (vs GitHub Actions):**
- ❌ No job dependencies (`needs`) — all steps in a workflow are strictly sequential
- ❌ No parallel jobs — single linear pipeline per workflow file
- ❌ No inter-run caching primitive — no equivalent to `actions/cache`
- ❌ No concurrency control — no `cancel-in-progress`
- ❌ No environment approvals — no GitHub Environments equivalent
- ❌ No matrix builds
- ❌ No built-in coverage threshold enforcement
- ❌ No dependency graph submission

Tangled also provides **Webhooks** (push events, HMAC-signed, 3 retries with backoff).

## Caching Profile (Corrected)

### What IS cached (between runs, via Docker layer caching)

Nixery builds OCI images with each nixpkgs package in a **separate Docker layer**. Docker reuses pre-existing layers, so any nixpkgs dependency declared in the `dependencies` block — `mise`, `nodejs`, `shellcheck`, `hurl`, `sqlite` — is cached at the Docker level between runs.

This is confirmed by the Tangled team: *"caching for commonly used packages is free thanks to Docker (pre-existing layers get reused)."* — [Introducing Spindle blog post](https://blog.tangled.org/ci/)

### What is NOT cached (fetched/compiled fresh every run)

| Artifact | Reason |
|----------|--------|
| Elixir 1.20.0-rc.4, Erlang 28.5 | Not in nixpkgs; `mise install` downloads fresh each run |
| `mix deps` + `_build` | No directory-level cache primitive in Spindle |
| `npm` packages + asset builds | Same — no cache primitive |
| Fluxon private Hex repo packages | Fetched each run |

### Within a run

Per the blog post: *"the `/tangled/workspace` and `/nix` volumes persisted across steps."* So within a single workflow run, compiled artifacts are available to subsequent steps. But between runs, everything resets except the Nixery Docker layers.

### Potential caching strategy: Custom Nix derivation for Elixir 1.20.0-rc.4

Spindle supports **custom registries** in the dependencies block. If Elixir 1.20.0-rc.4 were packaged as a Nix derivation and made available via a custom registry (e.g., hosted on Tangled itself), it would benefit from the same Docker layer caching as other nixpkgs packages. This would eliminate the biggest uncached download.

Similarly, Erlang 28.5 could be pinned via a custom derivation if not in nixpkgs.

## Dependency Availability in Nixpkgs

| Tool | In nixpkgs stable? | Version | Notes |
|------|-------------------|---------|-------|
| `elixir` | ✅ | 1.18.4 / 1.19.5 | **Not 1.20.0-rc.4** — must use mise or custom Nix derivation |
| `erlang` | ✅ | via beam packages | OTP versions tied to package sets |
| `nodejs` | ✅ | Yes | |
| `mise` | ✅ | 2025.11.7 | Can install exact Elixir/Erlang/Node from mise.toml |
| `shellcheck` | ✅ | Yes | |
| `hurl` | ✅ (likely) | | |
| `sqlite` | ✅ | Yes | |
| `credo` | ❌ | Elixir mix task | Must install via mix after Elixir is available |
| `sobelow` | ❌ | Elixir mix task | Same |
| `mix_audit` | ❌ | Elixir mix task | Same |

The workflow pattern with mise:
1. Add `mise` as a nixpkgs dependency (cached via Docker layers ✅)
2. `mise install` to fetch Elixir 1.20.0-rc.4, Erlang 28.5, Node 25.9.0 (NOT cached ❌)
3. Run existing mise tasks

## Implementation Routes

### Route A: Pure Spindle — Single Linear Workflow
One `.tangled/workflows/ci.yml` that runs lint → test → deploy sequentially.

**Pros:** Simplest — one file, fully self-contained on Tangled.
**Cons:** Slowest (no parallelism between lint+test), deploy runs on every PR push to main, no separation of concerns.

### Route B: Multiple Spindle Workflows — Split CI/CD
Separate files: `lint.yml`, `test.yml`, `deploy.yml`. Deploy is manual-trigger only.

**Pros:** Lint and test can trigger on PRs, deploy is intentional. Better separation of concerns.
**Cons:** No enforcement that test passes before manual deploy. Lint and test still run sequentially within each workflow.

### Route C: Spindle for CI + Webhook for Deploy
Spindle handles lint+test on PRs. A Tangled webhook on push to main triggers Coolify deployment via an external endpoint.

**Pros:** Deploy runs independently. Can add gating logic in webhook receiver.
**Cons:** Requires a webhook receiver (external service). More infrastructure.

### Route D: Spindle for All — Lean Pipeline (Accept Gaps)
Full pipeline on Spindle but accept the missing features. Configure longer timeout, accept sequential runs, use manual deploy trigger.

**Pros:** Fully native Tangled experience.
**Cons:** All gaps accepted as-is. May frustrate PR workflow.

### Route E: Mirror to GitHub + Keep Actions
Mirror the Tangled repo to GitHub (or use Tangled as a mirror of GitHub) and keep existing Actions.

**Pros:** Zero CI changes. All existing features preserved.
**Cons:** Not "replicating CI on tangled.org." Maintains GitHub dependency. Mirror sync complexity.

## Additional: Custom Nix Derivation Strategy (Orthogonal Enhancement)

Regardless of route chosen, a custom Nix derivation for Elixir 1.20.0-rc.4 could be hosted on Tangled as a custom registry, making it available as a cached nixpkgs-style dependency. This eliminates the mise download bottleneck (~2-5 min per run) and leverages Docker layer caching. This is an orthogonal optimization that benefits any Spindle-based route.
