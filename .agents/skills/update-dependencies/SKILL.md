---
name: update-dependencies
description: Use when the user asks to update, upgrade, or refresh project dependencies, or when outdated dependencies need attention. Also use when the user mentions "outdated", "bump", "upgrade", or asks about dependency versions — even if they don't say "update dependencies" explicitly.
---

# Update Dependencies

This project has five dependency categories checked by `mise run dev:outdated`:
NPM packages, Tailwind, ESBuild, Sqlean (SQLite extensions), and Mix (Hex) packages.
Dependabot handles GitHub Actions, Docker, Mix, and NPM updates via PRs, but the
user may still want to update manually — especially for tooling (Tailwind, ESBuild,
Sqlean) which Dependabot doesn't cover.

## Workflow

### 1. Check what's outdated

Run `mise run dev:outdated`. Read the summary table at the end — it has three columns:
Dependency, Status, and Next Step.

If mix dependencies are outdated, the output usually contains a hex.pm diff preview
link (looks like `https://hex.pm/l/FR8QK`). Offer the user the option to open it in
the browser for manual inspection before proceeding.

### 2. Assess the updates

Before running any update commands, check for major version bumps in the outdated
output. For major bumps (e.g., 1.x → 2.x), look up the changelog or migration guide
before updating — breaking changes may require code modifications.

If nothing is outdated, stop here and tell the user.

### 3. Apply updates

For each outdated category, run the command from the Next Step column. You have two
options depending on what the user prefers:

- **Bulk update**: run `mise run dev:update` to update everything at once.
- **Selective update**: run individual commands from the summary table one at a time.

When in doubt, ask the user which approach they prefer.

### 4. Verify

Run these checks after updating:

1. `mise run dev:outdated` — confirm everything is now up to date
2. `mix compile` — catch compilation errors early
3. `mix assets.build` — verify JS/CSS builds succeed (this depends on compiled
   Elixir code, so it must run after `mix compile`). This matters because NPM,
   Tailwind, and ESBuild updates can break the asset pipeline.
4. `mise run dev:lint` — catch formatting or credo issues introduced by updates
5. `mix test` — verify nothing is broken

### 5. Commit

Follow the project's commit conventions.

If a major version bump required code changes, those changes belong in the same commit
as the dependency bump — not in a separate commit.
