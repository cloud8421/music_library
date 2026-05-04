---
id: ML-37
title: Fix production migration strategy mismatch
status: Done
assignee: []
created_date: "2026-04-20 08:53"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/141"
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-30 · updated 2026-03-30 · closed 2026-03-30_

## Summary

Production releases are configured to skip boot-time migrations even though the codebase and docs state that migrations run automatically on startup.

## Why This Matters

A deploy can start successfully against an outdated schema, creating a real risk of runtime failures or subtle data corruption after deploys.

## Evidence

- `MusicLibrary.Application` wires `Ecto.Migrator` with `skip: skip_migrations?()`.
- `skip_migrations?/0` returns `true` whenever `RELEASE_NAME` is set (the release case).
- `rel/overlays/bin/server` only starts the release and does not run `rel/overlays/bin/migrate`.
- `scripts/prod/deploy.hurl` triggers a deploy and health checks, but does not invoke the migrate script.
- `docs/architecture.md` and `docs/production-infrastructure.md` both claim migrations run automatically on boot.

## Affected Files

- `lib/music_library/application.ex`
- `rel/overlays/bin/server`
- `rel/overlays/bin/migrate`
- `docs/architecture.md`
- `docs/production-infrastructure.md`

## Acceptance Criteria

<!-- AC:BEGIN -->

- Production deploys cannot start on an unmigrated schema.
- The documented migration strategy matches the implemented one.
- There is at least one automated check covering the chosen behavior.
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Production deploys cannot start on an unmigrated schema.
- [ ] #2 The documented migration strategy matches the implemented one.
- [ ] #3 There is at least one automated check covering the chosen behavior.
<!-- AC:END -->
