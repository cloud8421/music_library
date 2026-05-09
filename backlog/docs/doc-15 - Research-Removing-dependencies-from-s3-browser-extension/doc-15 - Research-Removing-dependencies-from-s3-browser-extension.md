---
id: doc-15
title: Research Removing dependencies from s3-browser extension
type: specification
created_date: "2026-05-09 08:31"
updated_date: "2026-05-09 08:48"
tags:
  - pi-extension
  - s3-browser
  - research
---

# Research: Removing dependencies from s3-browser extension

## Current state

The s3-browser pi extension (`.pi/extensions/s3-browser/`) uses `@aws-sdk/client-s3` v3.787.0 as its sole npm dependency. This single package pulls in ~150+ transitive dependencies across `@aws-sdk/*`, `@aws-crypto/*`, `@smithy/*`, `fast-xml-parser`, `tslib`, and others.

The extension only performs one API operation: **ListObjectsV2** against an S3-compatible object storage endpoint (`nbg1.your-objectstorage.com` — Hetzner Object Storage). It uses:

- Static credentials (`LITESTREAM_ACCESS_KEY_ID`, `LITESTREAM_SECRET_ACCESS_KEY`)
- Path-style endpoint (`forcePathStyle: true`)
- No credential chain resolution, no STS, no SSO, no IMDS

The S3 ListObjectsV2 REST API is a simple `GET /?list-type=2&prefix=...` with AWS SigV4 authentication. The response is XML.

## Implementation routes

### Route A: Full zero-dependency client

**Implement SigV4 signing + HTTP request + XML parsing using only Node.js built-in modules.**

Replace the entire `@aws-sdk/client-s3` usage with ~200 lines of custom TypeScript using:

- `crypto.createHmac("sha256", ...)` — for SigV4 signing key derivation and request signature
- `fetch` (built-in since Node 18) — for HTTP requests with AbortSignal support
- Regex-based XML extraction — for parsing the simple, well-known ListObjectsV2 response schema

**SigV4 signing** implementation (~100-120 lines):

1. Derive signing key: `HMAC-SHA256(region, HMAC-SHA256(service, HMAC-SHA256("aws4_request", HMAC-SHA256(date, "AWS4" + secret))))`
2. Build canonical request (HTTP method, URI, query string, headers, signed headers, payload hash)
3. Build string to sign (algorithm, timestamp, scope, hash of canonical request)
4. Calculate signature and assemble Authorization header
5. Set `x-amz-content-sha256` and `x-amz-date` headers

**XML parsing** (~40-50 lines):

- The ListObjectsV2 response uses a fixed, simple XML schema
- Extract `<Key>`, `<Size>`, `<LastModified>` from each `<Contents>` block via regex
- Extract `<IsTruncated>` and `<NextContinuationToken>` for pagination
- No full XML DOM needed

**Pros:**

- Truly zero dependencies — eliminates the entire supply-chain risk
- Total code is small and auditable (~200 lines)
- SigV4 is a well-documented, deterministic algorithm; easy to verify correctness
- The extension has no XML namespace complexities or edge cases to worry about

**Cons:**

- Must implement SigV4 correctly (though straightforward and well-specified)
- Must handle edge cases in XML parsing (empty response, missing fields, XML namespaces in the response)

**Dependency surface after change:** 0 npm packages (only Node.js built-ins)

---

### Route B: Minimal dependency — SigV4 signing library (`aws4`)

Use the `aws4` npm package (single-file, ~200 lines) for signing, and Node.js built-in modules for HTTP and XML parsing.

The `aws4` package is a well-established, minimal library that only signs requests — no HTTP client, no credential resolution, no XML parsing. It is a single-file package with **0 transitive dependencies** (verified: v1.13.2 has an empty `dependencies` field). It's widely used in production and hasn't needed an update in 2 years.

**Pros:**

- No need to implement SigV4 manually (reduces risk of signing bugs)
- Drastically reduced dependency surface: 1 package vs ~150
- `aws4` is auditable in minutes (single file, ~200 lines)
- Equally minimal in supply-chain terms as Route A (0 transitive deps)

**Cons:**

- Still introduces an external dependency (though extremely low-risk: single-file, 0-dep, 2-year-stable)
- Slightly less educational value (doesn't demonstrate SigV4 internals)
- `aws4` is designed for Node.js `http.request` options; must bridge to `fetch` by extracting `headers` from the signed options object and constructing the full URL

**Dependency surface after change:** 1 npm package (`aws4`, 0 transitive dependencies)

---

### Route C: AWS SDK minimal subset

Replace `@aws-sdk/client-s3` with only the credential + signing packages from the AWS SDK, making HTTP calls manually.

For example: `@aws-sdk/credential-provider-node` + `@smithy/signature-v4` + Node.js `fetch`.

**Pros:**

- Uses battle-tested AWS signing implementation
- Keeps credential chain resolution (not needed for this use case)

**Cons:**

- Still pulls in ~20-30 packages (many from `@smithy/*`)
- Doesn't fully address the supply-chain concern
- Over-engineered for static-credential use case
- Adds credential resolution features we don't use (IMDS, SSO, STS, profiles)

**Dependency surface after change:** ~20-30 npm packages

---

### Route D: S3 presigned URLs (if supported by Hetzner Object Storage)

Instead of SigV4 signing at request time, generate a presigned URL for the ListObjectsV2 operation and fetch it with a simple HTTP GET.

**Pros:**

- No signing code needed in the extension
- Could be pre-generated and stored as an env var

**Cons:**

- Presigned URLs expire; need regeneration mechanism
- Hetzner Object Storage may not support presigned URLs for ListObjectsV2
- Pagination with presigned URLs is awkward (each page needs a new URL)
- Doesn't eliminate dependencies — just shifts the signing to another tool

## Final decision

**Route B (`aws4` + Node.js built-ins) was chosen for implementation (see task ML-173).**

Route A (full zero-dependency) was the initial recommendation. However, on closer analysis, `aws4` was confirmed to have **0 transitive dependencies** (not ~3 as initially estimated), making it equally minimal in supply-chain terms as Route A. Given this, Route B was preferred because it eliminates all SigV4 signing implementation risk at zero additional supply-chain cost.

The `aws4` package is a single-file, 200-line, battle-tested library that hasn't needed an update in 2 years. The implementation bridges `aws4`'s `http.request`-style output to `fetch` by extracting signed headers and constructing the full URL — a thin wrapper of ~10-15 lines.
