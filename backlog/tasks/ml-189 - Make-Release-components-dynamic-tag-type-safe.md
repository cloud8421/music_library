---
id: ML-189
title: Make Release component's dynamic tag type-safe
status: To Do
assignee: []
created_date: "2026-05-19 08:42"
updated_date: "2026-05-19 09:10"
labels:
  - audit
  - liveview
  - components
  - type-safety
dependencies: []
documentation:
  - >-
    audits/phase1-async-message-coverage/doc-24 -
    Audit-Report-LiveComponent-→-Parent-handle_info-Coverage-Phase-1.md
modified_files:
  - lib/music_library_web/components/release.ex
  - lib/music_library_web/live/scrobble_live/release_show.ex
  - lib/music_library_web/live/collection_live/show.ex
priority: low
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

The Release component (lib/music_library_web/components/release.ex:82) uses `send(self(), {tag, release})` where `tag` is a dynamic assign (`on_release_loaded`). While correctly handled today, if a future consumer sets a non-atom tag, pattern matching in `handle_info` would fail silently since clauses match on atoms like `:release_loaded`.

**Fix:**

1. Remove the `on_release_loaded` attribute from the Release component — the nil-check conditional is an anomaly; every other LiveComponent in the codebase sends messages unconditionally.
2. Always send `{__MODULE__, {:loaded, release}}` from `notify_release_loaded/2`.
3. Update ScrobbleLive.ReleaseShow's `handle_info` to match `{MusicLibraryWeb.Components.Release, {:loaded, release}}` and remove the `on_release_loaded={:release_loaded}` assign from its template.
4. Add a no-op `handle_info` clause in CollectionLive.Show so the message is properly consumed (not silently dropped as an unhandled message).

**Source:** Audit doc-24 (Phase 1), Recommendation #1.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Release component's `notify_release_loaded/2` always sends `{__MODULE__, {:loaded, release}}` (no nil check, no `on_release_loaded` attribute)
- [ ] #2 ScrobbleLive.ReleaseShow: `handle_info` matches `{MusicLibraryWeb.Components.Release, {:loaded, release}}`, and `on_release_loaded={:release_loaded}` removed from template
- [ ] #3 CollectionLive.Show: has a no-op `handle_info({MusicLibraryWeb.Components.Release, {:loaded, _release}}, socket)` clause
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

## Implementation Plan

### 1. Release component (`lib/music_library_web/components/release.ex`)

In `notify_release_loaded/2`, remove the `case`/nil-check and always send:

```elixir
defp notify_release_loaded(_socket, release) do
  send(self(), {__MODULE__, {:loaded, release}})
end
```

Remove the `on_release_loaded` attribute from the LiveComponent — it was only used by `notify_release_loaded/2` and is no longer needed.

### 2. ScrobbleLive.ReleaseShow (`lib/music_library_web/live/scrobble_live/release_show.ex`)

Update `handle_info` to match the new message shape:

```elixir
def handle_info({MusicLibraryWeb.Components.Release, {:loaded, release}}, socket) do
  {:noreply, assign(socket, :page_title, page_title(release))}
end
```

Remove `on_release_loaded={:release_loaded}` from the `<.live_component>` call in the template.

### 3. CollectionLive.Show (`lib/music_library_web/live/collection_live/show.ex`)

Add a no-op `handle_info` clause (place it alongside the existing component-message handlers around line 338-469):

```elixir
def handle_info({MusicLibraryWeb.Components.Release, {:loaded, _release}}, socket) do
  {:noreply, socket}
end
```

### Verification

1. Open a release from the scrobble flow (ScrobbleLive.ReleaseShow) — page title should update with the release name after loading.
2. Open a release sheet from a record in CollectionLive.Show — the sheet should render correctly with no unhandled-message warnings.
3. Run `mix test test/music_library_web/components/release_test.exs` — all existing Release component tests pass.
4. Confirm `on_release_loaded` no longer appears in either LiveView template or the Release component.
<!-- SECTION:NOTES:END -->
