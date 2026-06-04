# SQLite JSONB storage spike

SQLite JSONB is worth evaluating because this application stores large MusicBrainz,
Last.fm, Discogs, and Wikipedia responses in SQLite JSON columns and runs hot
`json_extract` / `json_each` queries over some of them. The local benchmark shows
that SQLite JSONB itself is promising, but the current project should not adopt it
yet because true JSONB blobs do not round-trip through the current `ecto_sqlite3`
loader/dumper path.

## Recommendation

**No-go for production adoption now.**

SQLite JSONB reduced local table storage by 8.6–21.1% and made unindexed JSON scans
faster in representative queries. Indexed lookup paths were effectively unchanged
because expression indexes store the extracted scalar values.

The blocker is application compatibility: `ecto_sqlite3` v0.24.0 documents
`:map_type` and `:array_type`, but the local adapter code only changes migration
column affinity from `TEXT` to `BLOB`. The current dumpers still encode maps and
arrays as JSON text, and the current loader cannot decode true SQLite JSONB blobs.

No follow-up implementation tasks were created because the recommendation is no-go.

## Current hot JSON fields

| Table              | Schema               | JSON fields                                                                                                      | Hot usage                                                                                        |
| ------------------ | -------------------- | ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `scrobbled_tracks` | `LastFm.Track`       | embedded `artist`, embedded `album`, `last_fm_data`                                                              | `ListeningStats`, `ScrobbleRules`, maintenance queries, expression indexes on album/artist paths |
| `records`          | `Records.Record`     | `musicbrainz_data`, embedded `artists`, `genres`, `release_ids`, `included_release_group_ids`, `dominant_colors` | collection search, FTS trigger mirror, `record_releases` trigger, selected-release enrichment    |
| `artist_infos`     | `Artists.ArtistInfo` | `musicbrainz_data`, `discogs_data`, `wikipedia_data`, `lastfm_data`                                              | artist pages, collection country enrichment, embedding context                                   |

`assets.properties` is also a `:map`, but it was not part of this hot-path spike.

## `ecto_sqlite3` JSONB configuration behavior

The adapter documentation says:

- `:map_type` defaults to `:string`; set to `:binary` to use SQLite JSONB.
- `:array_type` defaults to `:string`; set to `:binary` to use SQLite JSONB.

Local source inspection and evaluation showed these project-relevant details:

- Column type selection is controlled by `Application.get_env(:ecto_sqlite3, :map_type, :string)` and `Application.get_env(:ecto_sqlite3, :array_type, :string)` in `Ecto.Adapters.SQLite3.DataType`, not by the project’s existing `MusicLibrary.Repo` config blocks.
- The project currently sets neither option, so all existing `:map`, embedded-schema, and `{:array, _}` columns are `TEXT`.
- Setting those options to `:binary` makes new migrations emit `BLOB` columns for `:map` and `{:array, _}`.
- `Ecto.Adapters.SQLite3.Codec.json_encode/1` still returns JSON text.
- Dumpers for `:map`, `{:map, _}`, and `{:array, _}` call `json_encode/1`; they do not wrap values in SQLite `jsonb(...)` and do not bind them as blobs.
- `Codec.json_decode/1` sends Elixir binaries to the JSON library. True SQLite JSONB is returned as a non-UTF-8 binary blob, so decoding fails.

Verification example:

| Check                                                         | Result               |
| ------------------------------------------------------------- | -------------------- |
| Default `DataType.column_type(:map, [])`                      | `TEXT`               |
| With `Application.put_env(:ecto_sqlite3, :map_type, :binary)` | `BLOB`               |
| `Codec.json_encode(%{"a" => 1})`                              | `{:ok, "{\"a\":1}"}` |
| `typeof(jsonb('{"a":1}'))`                                    | `blob`               |
| `Codec.json_decode(jsonb_blob)`                               | `:error`             |

Conclusion: the current configuration option is not sufficient for safe production
JSONB adoption in this project.

## Benchmark method

A temporary benchmark database was built from the local development database without
modifying the source database.

Environment:

| Item                                 | Value   |
| ------------------------------------ | ------- |
| App SQLite via `MusicLibrary.Repo`   | 3.53.2  |
| Python/CLI SQLite used for benchmark | 3.53.1  |
| `scrobbled_tracks` rows              | 105,836 |
| `records` rows                       | 1,239   |
| `artist_infos` rows                  | 394     |

Method:

1. Copy representative JSON columns into paired `_text` and `_jsonb` tables.
2. Convert JSONB tables with SQLite `jsonb(column)`.
3. Measure payload bytes with `length(column)`.
4. Measure table and index pages with `dbstat`.
5. Time repeated representative queries using Python `sqlite3`.
6. Create matching expression indexes for text and JSONB tables.
7. Compare insert/update paths using `jsonb(...)`, `json_set`, and `jsonb_set`.

## Storage measurements

### JSON payload bytes

| Dataset                                          |  Text bytes | JSONB bytes |       Delta |  Delta |
| ------------------------------------------------ | ----------: | ----------: | ----------: | -----: |
| `scrobbled_tracks` artist + album + Last.fm data | 109,504,560 |  96,738,789 | -12,765,771 | -11.7% |
| `records` metadata + artists + arrays            |  24,827,949 |  21,286,625 |  -3,541,324 | -14.3% |
| `artist_infos` metadata                          |  11,170,494 |  10,189,592 |    -980,902 |  -8.8% |

### Table storage from `dbstat`

| Object                   |  Text bytes | JSONB bytes |       Delta |  Delta |
| ------------------------ | ----------: | ----------: | ----------: | -----: |
| `scrobbled_tracks` table | 139,120,640 | 109,817,856 | -29,302,784 | -21.1% |
| `records` table          |  25,882,624 |  22,269,952 |  -3,612,672 | -14.0% |
| `artist_infos` table     |  11,493,376 |  10,506,240 |    -987,136 |  -8.6% |

## Query measurements

### Before expression indexes

| Query                                               | Text median | JSONB median | Change |
| --------------------------------------------------- | ----------: | -----------: | -----: |
| `scrobbled_tracks` album MBID full scan             |   39.740 ms |    25.758 ms | -35.2% |
| `scrobbled_tracks` top albums aggregate             |   95.817 ms |    65.680 ms | -31.5% |
| `records.release_ids` `json_each`                   |    0.609 ms |     0.365 ms | -40.0% |
| `records.musicbrainz_data` selected release extract |   20.570 ms |     2.570 ms | -87.5% |
| `artist_infos.musicbrainz_data` country extract     |    4.176 ms |     0.487 ms | -88.3% |

### After expression indexes

| Query                                           | Text median | JSONB median | Change |
| ----------------------------------------------- | ----------: | -----------: | -----: |
| `scrobbled_tracks` album MBID indexed lookup    |    0.057 ms |     0.062 ms |  +9.1% |
| `scrobbled_tracks` top albums indexed aggregate |    8.733 ms |     8.647 ms |  -1.0% |
| `records` artist-name indexed lookup            |    0.010 ms |     0.010 ms |  -2.1% |
| `artist_infos` area-name indexed lookup         |    0.010 ms |     0.010 ms |  +0.8% |

Expression index storage was identical between text JSON and JSONB because the index
stores extracted scalar values:

| Index group                           | Text bytes | JSONB bytes | Delta |
| ------------------------------------- | ---------: | ----------: | ----: |
| `scrobbled_tracks` hot indexes        | 14,528,512 |  14,528,512 |     0 |
| `records` sample artist-name index    |     28,672 |      28,672 |     0 |
| `artist_infos` sample area-name index |     12,288 |      12,288 |     0 |

`EXPLAIN QUERY PLAN` confirmed that SQLite used the matching expression indexes for
both text JSON and JSONB when the query expression text stayed as `json_extract(...)`.

## Insert and update measurements

| Operation                     |     Median | Notes                       |
| ----------------------------- | ---------: | --------------------------- |
| Insert text copy              |  89.679 ms | Copies existing text JSON   |
| Insert JSONB from text        | 169.698 ms | Converts with `jsonb(...)`  |
| Insert JSONB blob copy        |  73.373 ms | Copies already-JSONB blobs  |
| Update text with `json_set`   | 114.818 ms | Post-update `typeof= text`  |
| Update JSONB with `jsonb_set` |  74.921 ms | Post-update `typeof = blob` |
| Update JSONB with `json_set`  | 104.023 ms | Converts JSONB back to text |

The `json_set` result is important for this codebase because `ScrobbleRules` currently
uses `json_set` in SQL update fragments. If source columns became JSONB, those updates
would silently store text JSON unless they were changed to `jsonb_set`.

## Compatibility assessment

### JSON expression indexes

JSON expression indexes are compatible with JSONB input. Current expressions such as
`json_extract(album, '$.musicbrainz_id')` can still use indexes over JSONB columns.

The existing project rule still applies: query expressions must textually match the
index expression. Replacing `json_extract(...)` with `jsonb_extract(...)` or `->>`
would require corresponding index changes and query-plan verification.

### `json_each` and trigger-maintained tables

`json_each` works with JSONB input. The `record_releases` triggers that expand
`records.release_ids` should remain conceptually compatible, but they still need
migration tests because the `release_ids` source column would become a blob.

### FTS/search triggers

`records_search_index` is populated by triggers that copy `records.artists`,
`records.genres`, `records.release_ids`, and `records.included_release_group_ids`.

FTS5 can tokenize strings inside JSONB blobs, and `unaccent(jsonb(...))` returned text
in a local check. That is not enough for safe adoption because `Records.SearchIndex`
loads those mirrored columns through Ecto as arrays/embeds. If the FTS mirror stores
JSONB blobs, Ecto decoding fails for the same reason true JSONB fails elsewhere.

A future JSONB migration would need to keep FTS mirror columns as text JSON using
`json(column)` or replace mirrored JSON payloads with explicit text fields that the
search UI needs.

### Ecto schemas

Current Ecto schemas are not compatible with true JSONB blobs:

- `Records.Record.musicbrainz_data`
- `Records.Record` embedded `artists`
- `Records.Record` array fields
- `Records.SearchIndex` mirrored arrays/embeds
- `LastFm.Track` embedded `artist` / `album`
- `LastFm.Track.last_fm_data`
- `Artists.ArtistInfo` metadata maps

Before any production adoption, the project needs either upstream `ecto_sqlite3`
JSONB round-trip support or a local custom type/adapter patch that proves inserts,
updates, queries, embeds, arrays, and search-index loads all work.

### Tests

A future adoption task would need tests for:

- Ecto round-trip loading of true SQLite JSONB blobs for `:map`, `{:array, _}`,
  `embeds_one`, and `embeds_many`.
- Existing `Records`, `ListeningStats`, `Collection.Enrichment`, `ScrobbleRules`,
  and `Records.Search` query paths.
- Expression-index query plans for hot `json_extract` paths.
- Trigger behavior for `records_search_index` and `record_releases`.
- Rollback conversion from JSONB blobs back to text JSON.

### Backups and production rollback

Litestream/page-level backups are compatible with JSONB because JSONB is normal SQLite
BLOB storage. The operational risks are tooling and rollback:

- SQLite versions before 3.45 cannot use JSONB.
- JSONB is SQLite-internal and should be treated as opaque.
- Manual inspection is harder because values are blobs.
- `json_valid(column)` without flags reports `0` for JSONB; validation must use
  JSONB-aware checks such as `json_error_position(column) = 0` or SQLite's JSONB
  `json_valid` flags where available.
- A rollback must convert blobs back to text with `json(column)`, rebuild affected
  tables/indexes/triggers, and run verification before restarting the old app version.

## Migration strategy if this becomes viable later

Only reconsider JSONB after Ecto round-trip support is proven.

A future go-plan should be scoped as separate implementation work:

1. Confirm upstream `ecto_sqlite3` support or add a local custom type/adapter patch
   that encodes with SQLite `jsonb(...)` and decodes JSONB blobs safely.
2. Add test coverage for map, array, embedded-schema, FTS mirror, and trigger paths.
3. Rebuild affected tables because SQLite cannot alter existing column affinity in
   place in a way that rewrites all data safely.
4. Convert values with `jsonb(column)` and verify `typeof(column) = 'blob'`.
5. Replace mutating SQL that must preserve JSONB, such as `json_set`, with `jsonb_set`.
6. Keep `records_search_index` payload columns text-compatible or redesign the mirror.
7. Recreate expression indexes with exactly matching query expressions.
8. Take a production backup or `VACUUM INTO` copy before migration.
9. Provide rollback SQL that converts JSONB back to text JSON with `json(column)`.
10. Verify with query-plan checks, application tests, and sample production reads before
    marking the migration successful.
