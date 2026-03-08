---
name: update-dependencies
description: Use when the user asks to update, upgrade, or refresh project dependencies, or when outdated dependencies need attention
---

# Update Dependencies

## Workflow

1. Run `mise run dev:outdated` to check all dependency categories
2. Read the summary table at the end of the output — it has three columns: Dependency, Status, and Next Step
3. For each row marked as outdated, run the command listed in the Next Step column
4. Re-run `mise run dev:outdated` to confirm everything is up to date
5. Run `mix test` to verify nothing is broken
