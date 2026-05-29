---
id: ML-199
title: Extract shared record show LiveView logic
status: Done
assignee:
  - pi
created_date: "2026-05-29 05:29"
updated_date: "2026-05-29 05:39"
labels:
  - refactor
  - liveview
dependencies: []
references:
  - lib/music_library_web/live/collection_live/show.ex
  - lib/music_library_web/live/wishlist_live/show.ex
  - lib/music_library_web/live_helpers/record_actions.ex
  - lib/music_library_web/components/record_components.ex
documentation:
  - docs/architecture.md
  - docs/project-conventions.md
  - .agents/skills/ui-framework/SKILL.md
modified_files:
  - lib/music_library_web/live/collection_live/show.ex
  - lib/music_library_web/live/wishlist_live/show.ex
  - lib/music_library_web/live_helpers/record_show.ex
  - lib/music_library_web/components/record_components.ex
  - docs/architecture.md
  - priv/gettext/default.pot
  - priv/gettext/en/LC_MESSAGES/default.po
priority: medium
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Refactor the duplicated Collection and Wishlist record show LiveViews so common record detail rendering and event handling live in shared web-layer helpers/components while preserving page-specific collection and wishlist behavior.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Collection and Wishlist show pages reuse shared rendering for the common action bar, selected release row, release sheet, chat component, and edit modal.
- [x] #2 Collection and Wishlist show pages reuse shared handlers for common record actions, scrobble async handling, saved-record handling, chat-count refresh, and background record updates.
- [x] #3 Collection-specific behavior remains intact: notes, regenerate embeddings, purchased/listening details, similar records, print-enabled release sheet, and editable purchased_at field.
- [x] #4 Wishlist-specific behavior remains intact: purchase action, online store links, unreleased metadata, print-disabled release sheet, and hidden purchased_at field.
- [x] #5 Relevant focused tests or compile checks pass after the refactor.
- [x] #6 Architecture documentation reflects any new shared helper module added by the refactor.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Add `MusicLibraryWeb.LiveHelpers.RecordShow` for shared Collection/Wishlist show-page logic: common record assigns, delete navigation, scrobble release start/async result handling, saved-record assignment, chat-count refresh, background-update guard/toast, and shared page-title construction.
2. Extend `MusicLibraryWeb.RecordComponents` with focused shared components for the common show-page action bar, selected-release row, release sheet, chat component, and edit modal. Use slots for page-specific dropdown actions so collection and wishlist behavior stays explicit.
3. Refactor `CollectionLive.Show` and `WishlistLive.Show` to call the shared helper/components while keeping local page-specific sections and handlers: collection notes/regenerate/similar/listening details and wishlist purchase/online-store/current-date behavior.
4. Update `docs/architecture.md` to mention the new shared `LiveHelpers.RecordShow` module in the web utility modules table.
5. Run focused formatting/compile/tests for the touched LiveViews/components, then mark acceptance criteria based on the results.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Implemented shared `LiveHelpers.RecordShow` for common record loading, delete navigation, scrobble async handling, saved-record handling, chat refresh, and background update behavior. Added shared record show components for the action bar, selected release row, release sheet, chat component, and edit modal. Preserved collection-only notes/regenerate/listening/similar-record behavior and wishlist-only purchase/online-store/unreleased behavior. Verification: `mix compile --warnings-as-errors`, `mix test test/music_library_web/live/collection_live/show_test.exs test/music_library_web/live/wishlist_live/show_test.exs`, `mix gettext.extract --check-up-to-date`, `mix format --check-formatted ...`, and `mix credo --strict` all passed.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Refactored the Collection and Wishlist record show LiveViews to remove duplicated show-page rendering and lifecycle logic.

Changes:

- Added `MusicLibraryWeb.LiveHelpers.RecordShow` for shared record loading, page title assignment, delete navigation, common action dispatch, scrobble async handling, saved-record handling, chat refreshes, and guarded background record updates.
- Added shared `RecordComponents` functions for the common show action bar, selected release row, release sheet, record chat component, and edit modal.
- Updated `CollectionLive.Show` and `WishlistLive.Show` to compose the shared helpers/components while keeping collection-only and wishlist-only sections explicit.
- Updated gettext references after moving user-facing strings and documented `LiveHelpers.RecordShow` in `docs/architecture.md`.

Verification:

- `mix compile --warnings-as-errors`
- `mix test test/music_library_web/live/collection_live/show_test.exs test/music_library_web/live/wishlist_live/show_test.exs`
- `mix gettext.extract --check-up-to-date`
- `mix format --check-formatted lib/music_library_web/live_helpers/record_show.ex lib/music_library_web/components/record_components.ex lib/music_library_web/live/collection_live/show.ex lib/music_library_web/live/wishlist_live/show.ex`
- `mix credo --strict`
<!-- SECTION:FINAL_SUMMARY:END -->
