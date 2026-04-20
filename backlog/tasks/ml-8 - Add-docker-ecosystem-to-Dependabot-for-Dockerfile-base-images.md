---
id: ML-8
title: Add docker ecosystem to Dependabot for Dockerfile base images
status: Done
assignee: []
created_date: '2026-04-20 08:49'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/175'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-16 · updated 2026-04-17 · closed 2026-04-17_

## Summary

`.github/dependabot.yml` covers `github-actions`, `docker-compose`, `mix`, and `npm`, but not the Dockerfile base-image ARGs (`ELIXIR_VERSION`, `OTP_VERSION`, `DEBIAN_VERSION`). Updates are currently manual.

## Evidence

- `.github/dependabot.yml` — no `package-ecosystem: docker` entry targeting `Dockerfile`
- `Dockerfile` uses `ARG ELIXIR_VERSION=1.20.0-rc.4`, `ARG OTP_VERSION=28.4.2`, `ARG DEBIAN_VERSION=trixie-20260406-slim`

## Fix

Add to `.github/dependabot.yml`:

```yaml
- package-ecosystem: docker
  directory: /
  schedule:
    interval: daily
  open-pull-requests-limit: 5
```

Dependabot will open PRs bumping the base image ARGs; the `mise run dev:validate-docker-image` task (already in the project) will need to be run on those PRs to confirm `hexpm/elixir` tag availability on both `linux/amd64` and `linux/arm64`.

## Acceptance Criteria
<!-- AC:BEGIN -->
- Docker base-image updates surface as Dependabot PRs
- Existing `validate-docker-image` task runs in CI to gate them
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Docker base-image updates surface as Dependabot PRs
- [ ] #2 Existing `validate-docker-image` task runs in CI to gate them
<!-- AC:END -->
