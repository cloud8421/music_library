---
id: ML-181
title: >-
  Harden public asset transforms against unbounded resource consumption and
  cache amplification
status: Done
assignee: []
created_date: "2026-05-13 18:33"
updated_date: "2026-05-22 06:52"
labels:
  - security
  - api
  - ui
  - ready
dependencies: []
references:
  - doc-19 - GPT-5.5-Security-Review.md
  - >-
    backlog/completed/ml-35 -
    Harden-the-public-asset-endpoint-against-invalid-payloads.md
  - doc-21 - ML-181-Research-Public-Asset-Transform-Hardening-Routes.md
modified_files:
  - lib/music_library/assets/transform.ex
  - lib/music_library/assets/cache.ex
  - lib/music_library_web/controllers/asset_controller.ex
  - test/music_library/assets/transform_test.exs
  - test/music_library_web/controllers/asset_controller_test.exs
priority: medium
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

The unauthenticated `GET /public/assets/:transform_payload` endpoint decodes arbitrary JSON into a `%Transform{}` struct without validating `width` type, range, or maximum. An attacker with a valid asset hash (obtainable from public email image URLs) can craft unlimited variant payloads, forcing repeated native libvips resize attempts and amplifying ETS cache entries. Prior hardening (ml-35, commit `92a36b91`) fixed crashes from malformed payloads but left resource-control validation open.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Transform.decode/1 rejects payloads with string width (400 Bad Request)
- [x] #2 Transform.decode/1 rejects payloads with negative width (400 Bad Request)
- [x] #3 Transform.decode/1 rejects payloads with zero width (400 Bad Request)
- [x] #4 Transform.decode/1 rejects payloads with float width (400 Bad Request)
- [x] #5 Transform.decode/1 rejects payloads with width > 2048 (400 Bad Request)
- [x] #6 Transform.decode/1 accepts width: nil (original size, no resize)
- [x] #7 Transform.decode/1 accepts widths in 1..2048 (e.g., 96, 150, 480, 300, 2048)
- [x] #8 Canonical cache key collates variant payloads for the same (hash, width) into a single ETS entry
- [x] #9 Existing email image URLs (width: 96) continue to serve correctly
- [x] #10 API and authenticated asset routes continue to work unchanged
- [x] #11 Existing controller and LiveView tests pass without modification
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Objective Alignment

This plan addresses F1 from the security review by adding two complementary defenses:

1. **Width validation in `Transform.decode/1` and `decode!/1`** — Rejects payloads where `width` is not `nil` or a positive integer in range `1..2048`, preventing unbounded libvips thumbnail operations.
2. **Canonical cache key derivation** — Derives ETS cache keys from the validated `%Transform{hash, width}` struct instead of the raw payload string, eliminating cache amplification from variant JSON representations. HTTP ETag remains the raw payload to preserve existing test assertions and browser caching behavior.

Together these close both the resource consumption vector (arbitrary widths → native image processing) and the cache amplification vector (variant payload strings → unbounded ETS entries).

## Alternatives Considered

See `doc-21 - ML-181-Research-Public-Asset-Transform-Hardening-Routes.md` for full analysis. Route 3 (Combined) was selected as the simplest approach that fully addresses the finding. Route 4 (payload signing) is deferred as overkill for the single-operator threat model.

## Implementation Steps

### Step 1: Add width validation to `Transform.decode/1` and `decode!/1`

**File:** `lib/music_library/assets/transform.ex`

Add a private `valid_width?/1` guard that checks:

- `nil` → valid (no resize, serve original)
- Positive integer in `1..2048` → valid
- Anything else (string, negative, zero, float, very large) → invalid

Update `decode/1` to call `valid_width?/1` after parsing params, before constructing the struct. Return `{:error, :invalid_payload}` on validation failure.

Update `decode!/1` to delegate to `decode/1` and raise on the error tuple, keeping the `!` convention consistent:

```elixir
def decode!(payload) do
  case decode(payload) do
    {:ok, transform} -> transform
    {:error, :invalid_payload} -> raise ArgumentError, "invalid transform payload"
  end
end
```

This replaces the current `decode!/1` body which manually decodes base64/JSON without validation.

**Dependencies:** None
**Verification:**

- Run doctests: `mix test test/music_library/assets/transform_test.exs`
- The existing doctest (`width: 300`) still passes (300 is in range)
- The `decode!/1` doctest still passes (same valid payload now flows through validation)
- New unit tests (see Step 4) confirm rejection of edge cases

### Step 2: Add `canonical_key/1` to `Transform` module

**File:** `lib/music_library/assets/transform.ex`

Add a public function with a doctest:

```elixir
@doc """
    iex> Transform.canonical_key(%Transform{hash: "abc123", width: 96})
    "abc123:96"
"""
@spec canonical_key(t()) :: String.t()
def canonical_key(%__MODULE__{hash: hash, width: width}), do: "#{hash}:#{width}"
```

**Dependencies:** Step 1 (struct is now guaranteed valid)
**Verification:** Doctest confirms deterministic output

### Step 3: Update `AssetController` to use canonical cache key (ETS only)

**File:** `lib/music_library_web/controllers/asset_controller.ex`

Changes:

1. In `show/2`, after successful decode, compute `cache_key = Transform.canonical_key(transform)`
2. Pass `cache_key` (not `payload`) as the first argument to `cached_get/3`
3. In `cached_get/3`, use the first argument for `Cache.get/2` and `Cache.set/3` — rename the parameter from `payload` to `cache_key` for clarity
4. Keep `payload` as the HTTP ETag value (unchanged) — the `if-none-match` comparison in `show/2` and the `respond_with_cache/5` call continue to use the raw `payload` string

The separation is:

- **ETS cache key:** canonical `"hash:width"` — prevents cache amplification
- **HTTP ETag:** raw payload string — preserves existing test assertions on `get_resp_header(conn, "etag")`

**Dependencies:** Steps 1 and 2
**Verification:**

- Existing controller tests pass without modification: `mix test test/music_library_web/controllers/asset_controller_test.exs`
  - ETag assertions all check against the raw `payload`, which is unchanged
- Existing LiveView tests pass (they use Transform for cover URLs): `mix test test/music_library_web/live/collection_live/`

### Step 4: Add tests

**File:** `test/music_library/assets/transform_test.exs`

Add tests for `decode/1` with invalid widths:

- String width: `%{hash: "abc", width: "300"}` → `{:error, :invalid_payload}`
- Negative width: `%{hash: "abc", width: -1}` → `{:error, :invalid_payload}`
- Zero width: `%{hash: "abc", width: 0}` → `{:error, :invalid_payload}`
- Float width: `%{hash: "abc", width: 300.5}` → `{:error, :invalid_payload}`
- Very large width: `%{hash: "abc", width: 99999}` → `{:error, :invalid_payload}`
- Nil width: `%{hash: "abc", width: nil}` → valid
- Max allowed width: `%{hash: "abc", width: 2048}` → valid

Add a doctest for `canonical_key/1` (included in Step 2 above).

**File:** `test/music_library_web/controllers/asset_controller_test.exs`

Add integration tests:

- Payload with string width returns 400
- Payload with negative width returns 400
- Payload with very large width returns 400

Add test for cache amplification fix:

- Two variant payloads encoding the same (hash, width) produce the same cache entry (verify by checking that the second request does not trigger a new resize — either inspect ETS entry count or verify response timing)

**Dependencies:** Steps 1-3
**Verification:** `mix test` — all tests pass

### Step 5: Update inline module documentation

**File:** `lib/music_library/assets/transform.ex`

Update `@moduledoc` to document:

- The width validation rules: `nil` (original size) or positive integer `1..2048`
- The `canonical_key/1` function and its purpose for cache deduplication

**File:** `lib/music_library/assets/cache.ex`

Update the "Cache key" section of `@moduledoc`:

- Remove: "where `payload` is a transform parameter string (encoding width and asset hash)"
- Replace with: "where the key string is an opaque canonical transform key provided by the caller (currently `"hash:width"` from `Transform.canonical_key/1`)"

This reflects that Cache no longer knows or cares about the key's origin — it's just an opaque string.

**Dependencies:** Steps 1-3
**Verification:** Review updated doc output with `h MusicLibrary.Assets.Transform` and `h MusicLibrary.Assets.Cache`

## Architecture Impact Analysis

| Touchpoint                              | Impact                                                                                  |
| --------------------------------------- | --------------------------------------------------------------------------------------- |
| `MusicLibrary.Assets.Transform`         | Adds validation to `decode/1` and `decode!/1` + new `canonical_key/1` function          |
| `MusicLibraryWeb.AssetController`       | Uses canonical key for ETS Cache; HTTP ETag continues to use raw payload                |
| `MusicLibrary.Assets.Cache`             | No code change — key format remains `{string, format}`, but the string is now canonical |
| `MusicLibrary.Assets.Image`             | No change                                                                               |
| `MusicLibraryWeb.RecordsOnThisDayEmail` | No change — already uses valid width (96)                                               |
| `MusicLibraryWeb.CollectionJSON`        | No change — uses valid widths (nil, 150, 480)                                           |
| All LiveViews using Transform           | No change — no width or valid widths only                                               |
| Routes                                  | No change                                                                               |
| ETS cache                               | Existing entries invalidated on deploy restart (in-memory, expected)                    |
| HTTP caching (ETag/If-None-Match)       | No change — raw payload remains the ETag, preserving existing browser-cached responses  |
| External APIs                           | Not affected                                                                            |

## Performance Profile

- **`valid_width?/1`:** O(1) — two guard checks (`is_nil` and `is_integer and > 0 and ≤ 2048`)
- **`canonical_key/1`:** O(1) — string concatenation of two fields
- **Cache lookup:** Unchanged — single `:ets.lookup/2` per request
- **Memory:** Reduced — canonical keys collapse variant payloads into single entries
- **N+1 risk:** None — no new queries introduced
- **Latency impact:** Negligible (< 1µs for validation + key concatenation)

## Benchmarking Requirements

No benchmarks needed. The change removes work (fewer cache entries, early rejection of invalid payloads) rather than adding it.

## Cost Profile

No cost impact — no paid resources are consumed.

## Production Infrastructure Steps

No production changes required:

- No environment variables
- No database migrations
- No service provisioning
- ETS cache is in-memory and auto-clears on application restart during deploy
- No DNS, firewall, or Coolify configuration changes

## Documentation Updates

- **`doc-21`** (already created): Contains the full research analysis and route comparison
- **`Transform` `@moduledoc`**: Updated in Step 5 to document width validation rules and `canonical_key/1`
- **`Cache` `@moduledoc`**: Updated in Step 5 to describe the key as opaque rather than raw-payload-specific
- **`docs/architecture.md`**: No update needed — asset serving path is not documented at this granularity
- **`docs/project-conventions.md`**: No update needed
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

### Summary

Added two complementary defenses to the public asset transform endpoint:

1. **Width validation in `Transform.decode/1` and `decode!/1`** — Rejects payloads where `width` is not `nil` or a positive integer in `1..2048`. Invalid payloads return `{:error, :invalid_payload}` (400 Bad Request at the controller level). A private `valid_width?/1` guard handles nil, valid integer range, and all invalid cases (string, negative, zero, float, very large).

2. **Canonical cache key derivation** — Added `Transform.canonical_key/1` producing `"hash:width"` strings. `AssetController` now uses this as the ETS cache key while continuing to use the raw payload string for HTTP ETags. This collapses variant JSON payloads encoding the same (hash, width) into a single cache entry.

### Changes

- `lib/music_library/assets/transform.ex` — Added `@max_width 2048`, `valid_width?/1`, `canonical_key/1`, updated `decode/1`, `decode!/1`, and `@moduledoc`
- `lib/music_library/assets/cache.ex` — Updated `@moduledoc` Cache key section to describe key as opaque
- `lib/music_library_web/controllers/asset_controller.ex` — Uses `Transform.canonical_key/1` for ETS cache; HTTP ETag remains raw payload
- `test/music_library/assets/transform_test.exs` — 8 new unit tests for width validation edge cases + canonical_key doctest
- `test/music_library_web/controllers/asset_controller_test.exs` — 4 new integration tests (string/negative/large width rejection, cache amplification fix)

### Verification

- Full test suite: **1115 passed** (44 doctests, 1071 tests), 0 failures
- Existing controller and LiveView tests pass without modification
<!-- SECTION:FINAL_SUMMARY:END -->
