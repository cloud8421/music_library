---
id: ML-143
title: Cart-style multi-record import in Add Record modal
status: Done
assignee: []
created_date: '2026-04-20 10:00'
updated_date: '2026-04-20 12:34'
labels:
  - ui
  - liveview
  - import
dependencies: []
references:
  - backlog/ml-143/plan.md
  - backlog/ml-143/mockups.html
documentation:
  - backlog/ml-143/plan.md
  - backlog/ml-143/mockups.html
priority: medium
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replace the one-record-at-a-time import in the Add Record modal with a shopping-cart staging flow. Users build an ephemeral cart of `{release_group, format}` items from MusicBrainz search results, then import them all at once.

Batch-size behaviour mirrors the existing `BarcodeScan` split:
- 1 item → sync `start_async` with a spinner in the "Import 1 record" button; on success the modal closes and navigates to the new record.
- 2+ items → one Oban job per item via a new `ImportFromMusicbrainzReleaseGroup` worker; modal closes immediately and toasts "Importing N records in the background..."

Layout: mockup B (bottom tray) as baseline, mockup A (search left, cart right) on `md:` and up, with the import modal widened for the side-by-side view. Empty-cart state is shown in place.

Full technical plan and visual mockups are in the task folder — see References.

Affects both `CollectionLive.Index` and `WishlistLive.Index`. Barcode scanner flow and `StatsLive` single-record import are untouched.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 From the Collection or Wishlist index, clicking a format in the result dropdown adds a `{release_group, format}` item to the cart instead of importing immediately
- [ ] #2 The cart renders as a collapsible bottom tray on small viewports and as a right-hand panel on `md:` and up
- [ ] #3 The import modal widens on `md:` and up to fit the side-by-side layout
- [ ] #4 Result rows show an 'In cart' chip when the release group is already staged
- [ ] #5 Adding the same `{release_group_id, format}` pair twice is a no-op; the same release group with a different format creates a second cart row
- [ ] #6 Empty cart shows a visible placeholder with guidance to add records
- [ ] #7 Clicking 'Import 1 record' runs synchronously: button shows a spinner, modal stays open until done, then closes and navigates to the new record with an info toast
- [ ] #8 Clicking 'Import N records' (N>=2) enqueues one Oban job per item, toasts 'Importing N records in the background...', and closes the modal
- [ ] #9 A synchronous import failure leaves the modal open, preserves the cart, clears the spinner, and surfaces a friendly error toast
- [ ] #10 Cart state does not persist across modal close/reopen (ephemeral)
- [ ] #11 A new `MusicLibrary.Worker.ImportFromMusicbrainzReleaseGroup` Oban worker delegates to `Records.import_from_musicbrainz_release_group/2` with retry semantics matching the existing `ImportFromMusicbrainzRelease` worker
- [ ] #12 All new user-facing strings are wrapped in gettext and `.pot`/`.po` files are regenerated
- [ ] #13 LiveView tests cover: add-to-cart, remove, change format, dedup, 1-item sync path (assert navigation + toast, `refute_enqueued`), N-item async path (`assert_enqueued` per item)
- [ ] #14 New worker test covers happy path and error path
- [ ] #15 Obsolete `IndexActions.handle_import/3` and `handle_event("import", ...)` clauses in Collection/Wishlist index LiveViews are removed
- [ ] #16 `StatsLive.Index` import event handler is unchanged
<!-- AC:END -->
