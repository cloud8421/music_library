---
id: ML-109
title: Improve test suite
status: Done
assignee: []
created_date: "2026-04-20 08:59"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/57"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2025-10-25 · updated 2026-02-07 · closed 2026-02-07_

Comprehensive test coverage analysis. Key gaps identified:

**Critical (High Priority):**

- 9 of 10 background workers untested (FetchArtistImage, FetchArtistInfo, RecordRefreshMusicBrainzData, RefreshCover, PopulateGenres, GenerateRecordEmbedding, PruneArtistInfo, PruneAssetCache, ExtractColors)
- Scrobble LiveView — user-facing feature with Last.fm integration
- LastFmController — OAuth authentication flow

**Moderate Priority:**

- Universal Search LiveView
- ArchiveController (backup download)
- HealthController

**Low Priority:**

- Online Store Templates LiveView
- Notes management
- Stats detail LiveViews (top albums/artists)
- Color extraction feature

**Well-tested areas:** Collection/Wishlist/Artist/Stats LiveViews, core context modules (Records, Collection, Wishlist, Artists, ScrobbleActivity, ScrobbleRules), external API clients (MusicBrainz, LastFm, Discogs), AssetController, CollectionController, SessionController, Auth plug.

<!-- SECTION:DESCRIPTION:END -->
