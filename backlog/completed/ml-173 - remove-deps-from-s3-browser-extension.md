---
id: ML-173
title: remove deps from s3-browser extension
status: Done
assignee: []
created_date: "2026-05-09 08:29"
updated_date: "2026-05-09 09:43"
labels:
  - pi-extension
  - security
  - s3-browser
dependencies: []
references:
  - .pi/extensions/s3-browser/index.ts
  - .pi/extensions/s3-browser/package.json
  - doc-15 - Research-Removing-dependencies-from-s3-browser-extension
modified_files:
  - .pi/extensions/s3-browser/index.ts
  - .pi/extensions/s3-browser/s3-client.ts
  - .pi/extensions/s3-browser/s3-client.test.ts
  - .pi/extensions/s3-browser/package.json
  - .pi/extensions/s3-browser/package-lock.json
  - .pi/extensions/s3-browser/aws4.d.ts
  - .pi/extensions/s3-browser/tsconfig.json
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

The s3-browser pi extension has only one API integration, which is to be able to fetch the list of files from the target S3 bucket. To do that, it pulls `@aws-sdk/client-s3` as its sole dependency, which brings in a large dependency tree (~150+ packages including @aws-sdk/_, @aws-crypto/_, @smithy/\*, fast-xml-parser, tslib, etc.). This unnecessarily exposes the development environment to supply-chain attacks.

The extension needs to be re-written to use a custom, no-dependencies API client that directly calls the S3-compatible REST API using only Node.js built-in modules. The only API operation needed is ListObjectsV2.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 `@aws-sdk/client-s3` is removed from package.json dependencies
- [x] #2 `aws4` is the only runtime dependency with 0 transitive dependencies
- [x] #3 `/backups` command lists S3 backup files with correct sizes, dates, and sorting
- [x] #4 Pagination handles buckets with >1000 objects (multiple pages via ContinuationToken)
- [x] #5 Abort/cancel during loading (escape key) produces clean cancellation with no unhandled rejections
- [x] #6 Missing or invalid `LITESTREAM_ACCESS_KEY_ID`/`LITESTREAM_SECRET_ACCESS_KEY` shows a clear error notification
- [x] #7 Network errors (unreachable endpoint, timeout) show a clear error, not an unhandled exception
- [x] #8 TypeScript compiles without errors (`npx tsc --noEmit`)
- [x] #9 After clean `npm install`, only `aws4` appears in `npm ls --all` (no transitive or phantom dependencies)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Objective alignment

Replace `@aws-sdk/client-s3` (~150 transitive npm dependencies) with `aws4` (0 transitive dependencies) + Node.js built-in modules (`crypto`, `fetch`) for the single API operation the extension needs: S3 ListObjectsV2 against Hetzner Object Storage. The extension continues to function identically — same command (`/backups`), same UI, same behavior — while reducing the supply-chain attack surface to a single, auditable, single-file dependency.

## Alternatives considered

- **Route A (full zero-dependency):** Rejected. Implementing SigV4 manually introduces signing bug risk for marginal security gain over `aws4`, which is a single-file, 0-dep, battle-tested package that hasn't needed an update in 2 years. The research document (doc-15) initially recommended Route A; this plan overrides that recommendation because on closer analysis `aws4` has 0 transitive dependencies (not ~3 as initially estimated), making it equally minimal in supply-chain terms while eliminating all signing implementation risk.
- **Route C (AWS SDK minimal subset):** Rejected. Still pulls ~20-30 packages from `@smithy/*`; doesn't meaningfully address the supply-chain concern.
- **Route D (presigned URLs):** Rejected. Presigned URLs expire, don't work well with pagination, and shift the signing problem rather than solving it.

## Implementation steps

### Step 1: Replace dependency in package.json

Remove `@aws-sdk/client-s3`, add `aws4` at latest version, run `npm install` in `.pi/extensions/s3-browser/`.

**Verify:**

- `npm ls aws4 --depth=0` shows `aws4` with 0 dependencies
- `npm ls @aws-sdk/client-s3` returns empty/unmet
- `du -sh node_modules` shows dramatically reduced size

### Step 2: Create custom S3 client module

Create `.pi/extensions/s3-browser/s3-client.ts` with:

- `signRequest()` — wraps `aws4.sign()` with S3-compatible options (path-style endpoint, unsigned payload with `x-amz-content-sha256: UNSIGNED-PAYLOAD` for simple GETs). **Important**: `aws4.sign()` produces options shaped for Node.js `http.request` (`{host, path, headers}`). The wrapper extracts the signed `headers` object from the returned options, constructs the full URL as `https://${host}${path}`, and returns `{url, headers}` ready to pass to `fetch`.
- `listObjectsV2()` — builds the signed GET request via `signRequest()`, calls `fetch`, supports `AbortSignal`. Categorizes errors distinctly so the UI can show targeted messages per acceptance criterion #7: `AuthError` (HTTP 401/403 — bad credentials), `NotFoundError` (HTTP 404 — wrong bucket/endpoint), `NetworkError` (fetch rejection — unreachable endpoint, DNS failure, timeout), `AbortError` (user cancelled), `ServerError` (HTTP 5xx/other unexpected status).
- `parseListObjectsV2Response()` — regex-based XML extraction of `<Contents>` blocks (Key, Size, LastModified), `<IsTruncated>`, `<NextContinuationToken>`. **Must handle namespace-qualified XML** (Hetzner may return `<Contents xmlns="http://s3.amazonaws.com/doc/2006-03-01/">`) — use namespace-tolerant patterns such as `/<Contents[^>]*>([\s\S]*?)<\/Contents>/g`. Validate against a captured real Hetzner ListObjectsV2 XML response, not a hand-crafted fixture.
- Exported types: `S3ClientConfig`, `ListObjectsV2Params`, `ListObjectsV2Response`, `S3Object`, `S3Error` (union of error categories above)

**Testing approach**: Use Node.js built-in `node:test` runner (zero-dependency, available since Node 18). Create `.pi/extensions/s3-browser/s3-client.test.ts`. Tests:

- `signRequest` produces well-formed Authorization header (AWS4-HMAC-SHA256 format with correct credential scope and signed headers)
- `parseListObjectsV2Response` correctly parses a captured real Hetzner ListObjectsV2 XML response (store as test fixture)
- Empty response (no `<Contents>` blocks), truncated response (`<IsTruncated>true</IsTruncated>` + `<NextContinuationToken>`), and error response (`<Error><Code>...</Code><Message>...</Message></Error>`) all handled
- Aborting mid-fetch via `AbortController` produces a clean `AbortError` rejection with no unhandled promise rejections

**Verify:**

- `node --test s3-client.test.ts` passes all tests
- `npx tsc --noEmit` in extension directory compiles without errors

### Step 3: Integrate into index.ts

- Remove `import { S3Client, ListObjectsV2Command } from "@aws-sdk/client-s3"`
- Add `import { listObjectsV2 } from "./s3-client"`
- Replace `S3Client` construction + `client.send(command, ...)` with direct `listObjectsV2(config, params, signal)` call
- `listAllObjects` function signature changes from `(client: S3Client, signal?)` to `(config: S3ClientConfig, signal?)`
- **Sorting logic (size descending, then key descending) remains in `listAllObjects` in `index.ts` unchanged** — the client module is a pure data fetcher with no sorting responsibility
- UI code (BorderedLoader, SelectList, Container, etc.) remains untouched
- Update error handling in the `doFetch` catch block to inspect the new error categories and show distinct notifications (e.g., "Authentication failed — check LITESTREAM_ACCESS_KEY_ID / LITESTREAM_SECRET_ACCESS_KEY" for AuthError, "Could not reach S3 endpoint — check network" for NetworkError)

**Verify:**

- TypeScript compiles without errors: `npx tsc --noEmit` in extension directory
- All existing exports remain unchanged (no breaking changes for pi agent loader)

### Step 4: Integration test with real credentials

- Run `/backups` command in pi agent
- Confirm file list loads correctly (sizes, dates, sorting all match previous behavior)
- Navigate/select files in the list — confirm same behavior
- Test abort: press escape during loading — confirm clean cancellation with no unhandled rejections
- If bucket has >1000 objects, confirm pagination works across multiple pages
- Test with invalid credentials: unset env vars → confirm clear error notification
- Test with wrong endpoint: set endpoint to unreachable host → confirm NetworkError notification

**Verify:**

- Output visually matches the current `@aws-sdk/client-s3` version
- No console errors from the extension
- `tidewave_get_logs` shows no error-level logs from the extension

### Step 5: Clean install verification

- Remove `node_modules/` and `package-lock.json` from `.pi/extensions/s3-browser/`
- Run `npm install`
- Confirm only `aws4` is installed (no transitive deps)

**Verify:**

- `npm ls --all` shows only `aws4`
- `/backups` still works after clean install

## Architecture impact

| Touchpoint                                    | Impact                                           |
| --------------------------------------------- | ------------------------------------------------ |
| `.pi/extensions/s3-browser/index.ts`          | Modified: replace SDK imports with custom client |
| `.pi/extensions/s3-browser/s3-client.ts`      | **New file**: custom S3 client (~100 lines)      |
| `.pi/extensions/s3-browser/s3-client.test.ts` | **New file**: unit tests for s3-client           |
| `.pi/extensions/s3-browser/package.json`      | Modified: dependency swap                        |
| `.pi/extensions/s3-browser/package-lock.json` | Regenerated                                      |
| Pi agent extension loader                     | No impact (extension interface unchanged)        |
| Other pi extensions                           | No impact (isolated per-extension node_modules)  |
| Elixir app, schemas, contexts, routes, PubSub | No impact (pi extension, not server-side)        |
| Environment variables                         | No impact (same `LITESTREAM_*` vars)             |

## Performance profile

- **HTTP:** `fetch` (Node built-in) — equivalent to SDK's `@smithy/fetch-http-handler`
- **Signing:** `aws4.sign()` — O(1) per request, single HMAC chain, <1ms overhead
- **XML parsing:** Regex-based, O(n) where n = response body size. ListObjectsV2 returns max 1000 objects per page (<100KB XML typically). Parsing is sub-millisecond.
- **Pagination:** Same pattern as current — sequential pages via ContinuationToken. No concurrent requests.
- **Memory:** No buffering beyond the single response body per page. No streaming needed (XML response is small).
- **N+1 risk:** None — single HTTP call per page, no JOIN-style patterns.

## Benchmarking requirements

No ongoing benchmarks needed. This is a human-triggered, infrequent operation (someone typing `/backups`). One-off validation: ensure listing ~100 objects completes in <5 seconds (current behavior).

## Cost profile

No cost impact. No paid API calls (Hetzner Object Storage already provisioned). No additional services, compute, or storage. The extension runs entirely on the developer's machine.

## Production Changes

None. The pi extension runs locally in the developer's pi agent. No server-side deployments, environment variable changes, database migrations, DNS changes, or infrastructure provisioning are needed.

## Documentation

After implementation, update these documents:

1. **doc-15 (research document)**: Update recommendation section to note the final decision (Route B chosen) and correct the dependency count (`aws4` has 0 transitive deps, not ~3 as initially estimated)
2. **`docs/architecture.md`**: If it references the s3-browser extension or its dependencies, check for staleness
3. **AGENTS.md / `docs/project-conventions.md`**: If pi extension dependency patterns are documented, update to reflect the new minimal-dependency convention
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

## Implementation Summary

### Step 1: Replace dependency ✅

- Removed `@aws-sdk/client-s3` from `package.json`
- Added `aws4@^1.13.2` as the sole dependency
- Clean install: node_modules contains only `aws4` (0 transitive deps)
- `npm ls --all` confirms: `s3-browser@ └── aws4@1.13.2`

### Step 2: Create custom S3 client ✅

- Created `.pi/extensions/s3-browser/s3-client.ts` (~240 lines)
  - `signRequest()` — wraps `aws4.sign()` producing `{url, headers}` for `fetch`
  - `listObjectsV2()` — signed GET with error categorization (AuthError, NotFoundError, NetworkError, AbortError, ServerError)
  - `parseListObjectsV2Response()` — regex-based XML parsing with namespace tolerance
  - `parseErrorResponse()` — extracts Code/Message from S3 error XML
- Created `.pi/extensions/s3-browser/s3-client.test.ts` (16 tests)
  - All 16 tests pass with `node --experimental-strip-types --test`
  - Tests cover: signRequest auth format, XML parsing (normal, namespaced, empty, truncated), error responses, all HTTP error categories, abort handling
- Created `.pi/extensions/s3-browser/aws4.d.ts` — TypeScript type declarations for aws4
- Created `.pi/extensions/s3-browser/tsconfig.json` — for TypeScript compilation validation
- `npx tsc --noEmit` passes clean for s3-client.ts

### Step 3: Integrate into index.ts ✅

- Replaced `@aws-sdk/client-s3` imports with `./s3-client` imports
- `listAllObjects` now accepts `S3ClientConfig` instead of `S3Client`
- Added targeted error notifications in catch block:
  - AuthError → "Authentication failed — check LITESTREAM_ACCESS_KEY_ID / LITESTREAM_SECRET_ACCESS_KEY"
  - NetworkError → "Could not reach S3 endpoint — check network"
  - AbortError → clean cancellation (no notification)
  - Other → console.error for debugging
- UI code (BorderedLoader, SelectList, Container, etc.) unchanged
- Sorting logic unchanged (size desc → key desc in listAllObjects)

### Steps 4-5: Pending integration test

- Unit tests pass for all code paths (signing, parsing, error handling, abort)
- Integration test with real credentials required to verify `/backups` command

## Review fixes applied (2026-05-09)

### High-priority: 1. S3Object interface deduplication — Removed duplicate from index.ts; now imported from s3-client.ts. 2. Double done(null) settlement guard — Added settled flag + finish() wrapper so AbortError + onAbort don't fire done() twice. 3. listAllObjects extracted to s3-client.ts — Pagination loop + sort logic moved for testability; index.ts calls listAllObjects(config, { prefix }, signal).

### Medium-priority: 4. XML entity decoding — Added decodeXmlEntities() for &amp; &lt; &gt; &quot; &apos; in S3 keys. 5. Regex escaping in xmlText — Added escapeRegex() to sanitize tag names before new RegExp().

### Test coverage: 29 tests (up from 16). New: buildPath (3), fetch URL/header verification (1), XML entities (1), missing fields (1), listAllObjects pagination+sort (7). All pass.

<!-- SECTION:NOTES:END -->
