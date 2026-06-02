---
id: doc-31
title: "Architecture Direction: Stricter Modular Monolith"
type: specification
created_date: "2026-06-02 05:15"
tags:
  - architecture
  - modular-monolith
  - refactor
---

# Architecture Direction: Stricter Modular Monolith

## Problem

Phoenix contexts have kept database queries out of LiveViews, but they are still too loose as architectural boundaries for this application. The application now contains collection management, wishlist browsing, MusicBrainz import, metadata enrichment, Last.fm scrobbling, listening analytics, OpenAI chat, asset storage, production error handling, and maintenance workflows. A context-only architecture lets these concerns share schemas, call each other freely, and accumulate mixed read/write/workflow logic in large modules.

The recommended direction is a stricter **modular monolith**: keep a single Phoenix application and deployment, but make domain boundaries explicit, small, and enforceable.

## Current observations

The current architecture already has useful seams:

- Workers are thin wrappers in `lib/music_library/worker/` and mostly delegate to context modules.
- External integrations already follow a Facade/API/Config pattern, with `ErrorResponse` modules feeding `MusicLibrary.Worker.ErrorHandler`.
- `MusicLibrary.Records` has started splitting responsibilities into `Records.Search`, `Records.Import`, and `Records.Enrichment`.
- The web layer generally calls context modules instead of issuing direct Repo queries.

The main weaknesses are boundary looseness rather than missing infrastructure:

- Large contexts mix commands, queries, analytics, formatting, PubSub, and job scheduling. Examples include `MusicLibrary.ListeningStats`, `MusicLibrary.ScrobbleRules`, `MusicLibrary.Collection`, and `MusicLibrary.Artists`.
- Some web modules call external APIs directly, especially MusicBrainz, BraveSearch, and Last.fm paths used by scrobble, add-record, cover search, artist image search, and maintenance UI.
- `MusicLibrary.Collection` and `MusicLibrary.Wishlist` are read/query perspectives over `Records.Record`, while ownership state currently lives as `records.purchased_at`. This is pragmatic, but the ownership boundary should be made explicit.
- `MusicLibrary.Artists` owns persisted `ArtistInfo` but also coordinates MusicBrainz, Discogs, Wikipedia, Last.fm, asset updates, worker enqueues, and search queries.
- `MusicLibrary.ListeningStats` owns persisted Last.fm track data, analytics, search/listing, CRUD, backfill scheduling, PubSub, and matching records/artists.
- Cross-context calls are common and mostly informal. That makes it unclear which modules are public APIs versus implementation details.

## Recommendation

Adopt a stricter modular monolith with three reinforcing patterns:

1. **Public domain facades** for cross-domain calls.
2. **Use-case modules** for workflows and mutations.
3. **Command/query split** for modules with complex reads.
4. **Ports/adapters** only where external services currently leak into domain or web workflows.

This keeps the application as one deployable unit and avoids the overhead of an umbrella, event sourcing, or service decomposition.

## Proposed bounded areas

These are not necessarily immediate namespace renames. They are target ownership boundaries.

| Boundary     | Owns                                                                                                                                | Does not own                                                                     |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| Catalog      | Record/release/artist identity, MusicBrainz IDs, stored catalog metadata, record search primitives, similarity text inputs          | Whether a record is collected/wishlisted, Last.fm history, external HTTP details |
| Collection   | Owned records, wishlist state, record sets, collection/wishlist browsing, collection read models, records-on-this-day               | Raw MusicBrainz import mechanics, Last.fm API calls                              |
| Listening    | Scrobbled tracks, scrobble rules, listening analytics, Last.fm import/backfill, scrobble submission workflows                       | Collection record persistence except through public catalog/collection APIs      |
| Enrichment   | Metadata refresh workflows, external metadata coordination, cover/image discovery, genre/embedding generation, worker orchestration | Core record ownership decisions                                                  |
| Conversation | Chat persistence, prompts, streaming chat use cases for record/artist/collection                                                    | Direct collection/listening queries except through read APIs                     |
| Assets       | Binary assets, image resize/transform/cache/pruning                                                                                 | Metadata ownership decisions                                                     |
| Operations   | Maintenance, telemetry, production errors, health/admin workflows                                                                   | User-facing catalog/listening business rules                                     |

## Target module shape

Prefer evolving toward this shape incrementally:

```text
lib/music_library/
  catalog/
    catalog.ex              # public facade
    schemas/
    queries/
    commands/

  collection/
    collection.ex           # public facade
    queries/
    commands/
    read_models/

  listening/
    listening.ex            # public facade
    schemas/
    queries/
    commands/
    read_models/

  enrichment/
    enrichment.ex           # public facade for workflows
    commands/
    providers/              # behaviours/ports where useful

  conversation/
  assets/
  operations/
```

The exact names can remain closer to the existing project names at first. For example, `MusicLibrary.Records.Import` can become command-oriented before any `Catalog` rename is attempted.

## Boundary rules to codify

These rules matter more than folder names:

1. Web modules call public domain APIs or use-case modules, not external API clients directly.
2. Workers remain thin and call one use-case/command module.
3. Schemas stay pure: changesets and struct helpers only, no side effects.
4. Query modules do not mutate data, enqueue jobs, broadcast PubSub messages, or call external services.
5. Command/use-case modules may mutate state, enqueue jobs, broadcast events, and call providers.
6. Cross-domain calls go through public facades, not internal query/schema modules.
7. External service behaviours are introduced only where they reduce coupling or improve testability; do not wrap every helper preemptively.
8. Existing SQLite-specific query optimizations stay in query/read-model modules where they can be reviewed together.

## Suggested migration path

### Phase 1: Define seams without renaming everything

- Mark each current context as either facade, query module, command/use-case module, schema, or adapter.
- Add project-convention language that defines public domain APIs and internal modules.
- Identify direct external API calls in the web layer and route them through application use cases.
- Keep existing routes, schemas, migrations, and database layout unchanged.

### Phase 2: Split high-pressure modules

Good first candidates:

- `MusicLibrary.ListeningStats`
  - `ListeningStats.Queries` or `Listening.Queries`
  - `ListeningStats.Commands`
  - `ListeningStats.ReadModels.RecentActivity`
  - `ListeningStats.ReadModels.TopByPeriod`
- `MusicLibrary.Artists`
  - `Artists.Queries`
  - `Artists.Commands.RefreshInfo`
  - `Artists.Commands.RefreshImage`
  - `Artists.Commands.RefreshExternalData`
- `MusicLibrary.Collection`
  - `Collection.Queries`
  - `Collection.ReadModels.Summary`
  - `Collection.ReadModels.OnThisDay`
- `MusicLibrary.ScrobbleRules`
  - `ScrobbleRules.Queries`
  - `ScrobbleRules.Commands.ApplyRule`
  - `ScrobbleRules.Commands.ApplyAllRules`

The goal is not smaller files for their own sake. The goal is to separate read models, mutations, and workflow orchestration.

### Phase 3: Move web-owned provider calls into use cases

Examples:

- Scrobble search and release loading should call a MusicLibrary use case rather than `MusicBrainz` directly from LiveViews/components.
- Cover search and artist image search should go through record/artist image use cases rather than `BraveSearch` directly from form components.
- Last.fm profile/session validation should live behind a listening/account integration use case rather than maintenance/controller code calling `LastFm` directly.

### Phase 4: Introduce ports/adapters selectively

Start with external APIs whose response shapes or retry semantics leak into multiple areas:

- MusicBrainz release/release-group lookup
- Last.fm scrobbling and listening import
- BraveSearch image discovery/download
- OpenAI embeddings/chat

The existing Facade/API/Config modules can remain the concrete adapters. Behaviours should be placed at application boundary points, not around every function.

### Phase 5: Optional namespace consolidation

Only after seams are stable, consider renaming or re-bucketing modules into stronger bounded-context namespaces such as `Catalog`, `Listening`, `Enrichment`, and `Operations`. This should be done in small commits and only where it reduces ambiguity.

## Alternatives considered

| Alternative                | Fit           | Reason                                                                                                                   |
| -------------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Keep Phoenix contexts only | Weak          | Already showing pressure from mixed responsibilities and informal cross-context calls.                                   |
| Umbrella app               | Low initially | Adds config, migration, test, and dependency overhead without independent deployment needs.                              |
| Service decomposition      | Poor          | No evidence that separate runtimes or network boundaries solve the current problem.                                      |
| Event sourcing             | Poor          | The app does not currently need replay, full audit history, or event-derived state as its primary model.                 |
| Heavy DDD rewrite          | Risky         | Could improve language, but a big-bang rewrite would disrupt working LiveViews, workers, and SQLite query optimizations. |

## Practical first implementation slice

A low-risk first slice would be:

1. Extract `ListeningStats` analytics reads into query/read-model modules.
2. Keep `MusicLibrary.ListeningStats` as the public facade.
3. Move direct MusicBrainz calls from scrobble LiveViews/components into a small use-case module.
4. Add tests around the moved public functions before changing callers.
5. Update `docs/project-conventions.md` with public/internal boundary rules once the pattern is proven.

This slice exercises the new architecture without changing database structure, routes, workers, or external API clients.

## Non-goals

- Do not introduce an umbrella app as the first step.
- Do not split the application into services.
- Do not rename every context immediately.
- Do not move SQLite schema ownership until module boundaries are clearer.
- Do not add behaviours for every dependency by default.

## Success criteria

The refactor is successful if future feature work can answer these questions quickly:

- Which boundary owns this data?
- Is this function a command, query, read model, adapter, or facade?
- Which public API should another boundary call?
- Can a worker perform this job by delegating to one named use case?
- Can a LiveView load data without knowing external API or persistence details?
