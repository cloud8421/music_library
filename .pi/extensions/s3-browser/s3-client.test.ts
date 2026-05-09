/**
 * Tests for s3-client.ts using Node.js built-in node:test runner.
 *
 * Run with: node --experimental-strip-types --test s3-client.test.ts
 */

import { describe, it, beforeEach, afterEach, mock } from "node:test";
import * as assert from "node:assert/strict";

// We import the module under test. Since we're using --experimental-strip-types,
// direct TypeScript imports work.
import {
  signRequest,
  parseListObjectsV2Response,
  parseErrorResponse,
  listObjectsV2,
  listAllObjects,
  AuthError,
  NotFoundError,
  NetworkError,
  AbortError,
  ServerError,
} from "./s3-client.ts";

// ── Test helpers ────────────────────────────────────────────────────────────

const TEST_CONFIG = {
  endpoint: "nbg1.your-objectstorage.com",
  region: "nbg1",
  bucket: "ffmusiclibrary",
  accessKeyId: "TESTACCESSKEY",
  secretAccessKey: "TESTVAL123",
};

// ── signRequest tests ──────────────────────────────────────────────────────

describe("signRequest", () => {
  it("produces a well-formed Authorization header (AWS4-HMAC-SHA256)", () => {
    const result = signRequest(TEST_CONFIG, "/bucket/?list-type=2");

    assert.ok(result.url.startsWith("https://nbg1.your-objectstorage.com/"));
    assert.ok(typeof result.headers["authorization"] === "string");
    assert.ok(result.headers["authorization"].startsWith("AWS4-HMAC-SHA256"));
    assert.ok(
      result.headers["authorization"].includes("Credential=TESTACCESSKEY/"),
    );
    assert.ok(
      result.headers["authorization"].includes("/nbg1/s3/aws4_request"),
    );
    assert.ok(result.headers["authorization"].includes("SignedHeaders="));
    assert.ok(result.headers["authorization"].includes("Signature="));
  });

  it("includes x-amz-date and x-amz-content-sha256 headers", () => {
    const result = signRequest(TEST_CONFIG, "/bucket/?list-type=2");

    assert.ok(typeof result.headers["x-amz-date"] === "string");
    assert.equal(result.headers["x-amz-content-sha256"], "UNSIGNED-PAYLOAD");
  });

  it("preserves continuation token in URL", () => {
    const result = signRequest(
      TEST_CONFIG,
      "/ffmusiclibrary/?list-type=2&prefix=prod%2F&continuation-token=abc123",
    );

    assert.ok(result.url.includes("continuation-token=abc123"));
  });
});

// ── XML parsing tests ──────────────────────────────────────────────────────

// Real-world Hetzner Object Storage ListObjectsV2 XML response pattern.
// Note: Hetzner may include xmlns attributes.
const REAL_XML_RESPONSE = `<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Name>ffmusiclibrary</Name>
  <Prefix>prod/</Prefix>
  <KeyCount>3</KeyCount>
  <MaxKeys>1000</MaxKeys>
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>prod/db.sqlite3</Key>
    <LastModified>2025-12-01T10:30:00.000Z</LastModified>
    <ETag>"abc123"</ETag>
    <Size>1048576</Size>
    <StorageClass>STANDARD</StorageClass>
  </Contents>
  <Contents>
    <Key>prod/db.sqlite3-wal</Key>
    <LastModified>2025-12-01T10:30:05.000Z</LastModified>
    <ETag>"def456"</ETag>
    <Size>512</Size>
    <StorageClass>STANDARD</StorageClass>
  </Contents>
  <Contents xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
    <Key>prod/db.sqlite3-shm</Key>
    <LastModified>2025-12-01T10:30:10.000Z</LastModified>
    <ETag>"ghi789"</ETag>
    <Size>32768</Size>
    <StorageClass>STANDARD</StorageClass>
  </Contents>
</ListBucketResult>`;

// Hetzner-like namespace-qualified XML
const NAMESPACED_XML_RESPONSE = `<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Name>ffmusiclibrary</Name>
  <Prefix>prod/</Prefix>
  <KeyCount>2</KeyCount>
  <MaxKeys>1000</MaxKeys>
  <IsTruncated>true</IsTruncated>
  <NextContinuationToken>eyJNYXJrZXIiOiBudWxsLCAiYm90b190cnVuY2F0ZV9hbW91bnQiOiAxfQ==</NextContinuationToken>
  <Contents xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
    <Key xmlns="http://s3.amazonaws.com/doc/2006-03-01/">prod/wal/00000001.sqlite3-wal</Key>
    <LastModified xmlns="http://s3.amazonaws.com/doc/2006-03-01/">2025-12-02T08:00:00.000Z</LastModified>
    <Size xmlns="http://s3.amazonaws.com/doc/2006-03-01/">2048</Size>
  </Contents>
  <Contents>
    <Key>prod/wal/00000002.sqlite3-wal</Key>
    <LastModified>2025-12-02T09:00:00.000Z</LastModified>
    <Size>4096</Size>
  </Contents>
</ListBucketResult>`;

const EMPTY_RESPONSE = `<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Name>ffmusiclibrary</Name>
  <Prefix>empty/</Prefix>
  <KeyCount>0</KeyCount>
  <MaxKeys>1000</MaxKeys>
  <IsTruncated>false</IsTruncated>
</ListBucketResult>`;

const ERROR_RESPONSE = `<?xml version="1.0" encoding="UTF-8"?>
<Error>
  <Code>AccessDenied</Code>
  <Message>Access Denied</Message>
  <RequestId>TX1234567890</RequestId>
  <HostId>host-id-123</HostId>
</Error>`;

describe("parseListObjectsV2Response", () => {
  it("parses a real-world XML response correctly", () => {
    const result = parseListObjectsV2Response(REAL_XML_RESPONSE);

    assert.equal(result.objects.length, 3);
    assert.equal(result.isTruncated, false);
    assert.equal(result.nextContinuationToken, undefined);

    // First object
    assert.equal(result.objects[0].key, "prod/db.sqlite3");
    assert.equal(result.objects[0].size, 1048576);
    assert.equal(
      result.objects[0].lastModified.toISOString(),
      "2025-12-01T10:30:00.000Z",
    );

    // Second object
    assert.equal(result.objects[1].key, "prod/db.sqlite3-wal");
    assert.equal(result.objects[1].size, 512);

    // Third object (namespace-qualified)
    assert.equal(result.objects[2].key, "prod/db.sqlite3-shm");
    assert.equal(result.objects[2].size, 32768);
  });

  it("handles namespace-qualified XML (individual tag xmlns)", () => {
    const result = parseListObjectsV2Response(NAMESPACED_XML_RESPONSE);

    assert.equal(result.objects.length, 2);
    assert.equal(result.isTruncated, true);
    assert.equal(
      result.nextContinuationToken,
      "eyJNYXJrZXIiOiBudWxsLCAiYm90b190cnVuY2F0ZV9hbW91bnQiOiAxfQ==",
    );

    // Both objects should be parsed despite namespace differences
    assert.equal(result.objects[0].key, "prod/wal/00000001.sqlite3-wal");
    assert.equal(result.objects[0].size, 2048);
    assert.equal(result.objects[1].key, "prod/wal/00000002.sqlite3-wal");
    assert.equal(result.objects[1].size, 4096);
  });

  it("handles empty response (no Contents blocks)", () => {
    const result = parseListObjectsV2Response(EMPTY_RESPONSE);

    assert.equal(result.objects.length, 0);
    assert.equal(result.isTruncated, false);
    assert.equal(result.nextContinuationToken, undefined);
  });

  it("handles truncated response with next continuation token", () => {
    const result = parseListObjectsV2Response(NAMESPACED_XML_RESPONSE);

    assert.equal(result.isTruncated, true);
    assert.ok(typeof result.nextContinuationToken === "string");
    assert.ok(result.nextContinuationToken!.length > 0);
  });
});

describe("parseErrorResponse", () => {
  it("extracts Code and Message from S3 error XML", () => {
    const result = parseErrorResponse(ERROR_RESPONSE);

    assert.equal(result.code, "AccessDenied");
    assert.equal(result.message, "Access Denied");
  });
});

// ── HTTP error handling tests ───────────────────────────────────────────────

describe("listObjectsV2 error handling", () => {
  let originalFetch: typeof globalThis.fetch;

  beforeEach(() => {
    originalFetch = globalThis.fetch;
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
    mock.reset();
  });

  it("throws AuthError on HTTP 403", async () => {
    globalThis.fetch = mock.fn(() =>
      Promise.resolve(new Response(ERROR_RESPONSE, { status: 403 })),
    ) as unknown as typeof fetch;

    await assert.rejects(
      () => listObjectsV2(TEST_CONFIG, { prefix: "prod/" }),
      (err: unknown) => {
        assert.ok(err instanceof AuthError);
        return true;
      },
    );
  });

  it("throws AuthError on HTTP 401", async () => {
    globalThis.fetch = mock.fn(() =>
      Promise.resolve(new Response(ERROR_RESPONSE, { status: 401 })),
    ) as unknown as typeof fetch;

    await assert.rejects(
      () => listObjectsV2(TEST_CONFIG, { prefix: "prod/" }),
      AuthError,
    );
  });

  it("throws NotFoundError on HTTP 404", async () => {
    globalThis.fetch = mock.fn(() =>
      Promise.resolve(new Response("Not Found", { status: 404 })),
    ) as unknown as typeof fetch;

    await assert.rejects(
      () => listObjectsV2(TEST_CONFIG, { prefix: "prod/" }),
      NotFoundError,
    );
  });

  it("throws ServerError on HTTP 500", async () => {
    globalThis.fetch = mock.fn(() =>
      Promise.resolve(new Response("Internal Server Error", { status: 500 })),
    ) as unknown as typeof fetch;

    await assert.rejects(
      () => listObjectsV2(TEST_CONFIG, { prefix: "prod/" }),
      ServerError,
    );
  });

  it("throws NetworkError on fetch rejection", async () => {
    globalThis.fetch = mock.fn(() =>
      Promise.reject(new TypeError("fetch failed")),
    ) as unknown as typeof fetch;

    await assert.rejects(
      () => listObjectsV2(TEST_CONFIG, { prefix: "prod/" }),
      NetworkError,
    );
  });

  it("throws AbortError when signal is already aborted", async () => {
    const controller = new AbortController();
    controller.abort();

    // fetch should not be called when signal is already aborted
    globalThis.fetch = mock.fn(() =>
      Promise.resolve(new Response(EMPTY_RESPONSE, { status: 200 })),
    ) as unknown as typeof fetch;

    await assert.rejects(
      () => listObjectsV2(TEST_CONFIG, { prefix: "prod/" }, controller.signal),
      AbortError,
    );
  });

  it("throws AbortError when aborted mid-fetch", async () => {
    const controller = new AbortController();

    globalThis.fetch = mock.fn(
      (_url: string, init: { signal?: AbortSignal }) => {
        // Simulate abort mid-request
        const err = new DOMException("The operation was aborted", "AbortError");
        return Promise.reject(err);
      },
    ) as unknown as typeof fetch;

    await assert.rejects(
      () => listObjectsV2(TEST_CONFIG, { prefix: "prod/" }, controller.signal),
      AbortError,
    );
  });
});

// ── Successful response test ────────────────────────────────────────────────

describe("listObjectsV2 success", () => {
  let originalFetch: typeof globalThis.fetch;

  beforeEach(() => {
    originalFetch = globalThis.fetch;
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
    mock.reset();
  });

  it("returns parsed objects on HTTP 200", async () => {
    globalThis.fetch = mock.fn(() =>
      Promise.resolve(new Response(REAL_XML_RESPONSE, { status: 200 })),
    ) as unknown as typeof fetch;

    const result = await listObjectsV2(TEST_CONFIG, { prefix: "prod/" });

    assert.equal(result.objects.length, 3);
    assert.equal(result.isTruncated, false);
    assert.equal(result.objects[0].key, "prod/db.sqlite3");
    assert.equal(result.objects[0].size, 1048576);
  });

  it("calls fetch with the correct signed URL and headers", async () => {
    globalThis.fetch = mock.fn(() =>
      Promise.resolve(new Response(EMPTY_RESPONSE, { status: 200 })),
    ) as unknown as typeof fetch;

    await listObjectsV2(TEST_CONFIG, { prefix: "prod/" });

    const calls = (globalThis.fetch as ReturnType<typeof mock.fn>).mock.calls;
    assert.ok(Array.isArray(calls) && calls.length >= 1);
    const [url, init] = calls[0].arguments as [
      string,
      { headers?: Record<string, string> },
    ];
    assert.ok(url.startsWith("https://nbg1.your-objectstorage.com/"));
    assert.ok(url.includes("list-type=2"));
    assert.ok(url.includes("prefix=prod%2F"));
    assert.ok(typeof init.headers === "object");
    assert.ok(typeof init.headers["authorization"] === "string");
    assert.ok(init.headers["authorization"].startsWith("AWS4-HMAC-SHA256"));
  });
});

// ── buildPath tests (via listObjectsV2 + fetch mock inspection) ────────────

describe("buildPath (via listObjectsV2)", () => {
  let originalFetch: typeof globalThis.fetch;

  beforeEach(() => {
    originalFetch = globalThis.fetch;
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
    mock.reset();
  });

  it("builds path with prefix and max-keys", async () => {
    globalThis.fetch = mock.fn(() =>
      Promise.resolve(new Response(EMPTY_RESPONSE, { status: 200 })),
    ) as unknown as typeof fetch;

    await listObjectsV2(TEST_CONFIG, { prefix: "prod/", maxKeys: 500 });

    const [url] = (globalThis.fetch as ReturnType<typeof mock.fn>).mock.calls[0]
      .arguments as [string];
    assert.ok(url.includes("prefix=prod%2F"));
    assert.ok(url.includes("max-keys=500"));
  });

  it("includes continuation-token when provided", async () => {
    globalThis.fetch = mock.fn(() =>
      Promise.resolve(new Response(EMPTY_RESPONSE, { status: 200 })),
    ) as unknown as typeof fetch;

    await listObjectsV2(TEST_CONFIG, {
      prefix: "prod/",
      continuationToken: "tok-abc",
    });

    const [url] = (globalThis.fetch as ReturnType<typeof mock.fn>).mock.calls[0]
      .arguments as [string];
    assert.ok(url.includes("continuation-token=tok-abc"));
  });

  it("omits continuation-token when not provided", async () => {
    globalThis.fetch = mock.fn(() =>
      Promise.resolve(new Response(EMPTY_RESPONSE, { status: 200 })),
    ) as unknown as typeof fetch;

    await listObjectsV2(TEST_CONFIG, { prefix: "prod/" });

    const [url] = (globalThis.fetch as ReturnType<typeof mock.fn>).mock.calls[0]
      .arguments as [string];
    assert.ok(!url.includes("continuation-token"));
  });
});

// ── XML entity decoding tests ──────────────────────────────────────────────

const ENTITY_XML_RESPONSE = `<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Name>ffmusiclibrary</Name>
  <Prefix>prod/</Prefix>
  <KeyCount>2</KeyCount>
  <MaxKeys>1000</MaxKeys>
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>prod/foo&amp;bar/data.sqlite3</Key>
    <LastModified>2025-12-01T10:30:00.000Z</LastModified>
    <Size>2048</Size>
  </Contents>
  <Contents>
    <Key>prod/with &lt;angle&gt; brackets.sqlite3-wal</Key>
    <LastModified>2025-12-01T10:30:05.000Z</LastModified>
    <Size>512</Size>
  </Contents>
</ListBucketResult>`;

describe("parseListObjectsV2Response — entities", () => {
  it("decodes XML character entities in keys", () => {
    const result = parseListObjectsV2Response(ENTITY_XML_RESPONSE);

    assert.equal(result.objects.length, 2);
    assert.equal(result.objects[0].key, "prod/foo&bar/data.sqlite3");
    assert.equal(result.objects[0].size, 2048);
    assert.equal(
      result.objects[1].key,
      "prod/with <angle> brackets.sqlite3-wal",
    );
    assert.equal(result.objects[1].size, 512);
  });
});

// ── Missing optional fields tests ──────────────────────────────────────────

const MISSING_FIELDS_XML = `<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Name>ffmusiclibrary</Name>
  <Prefix>prod/</Prefix>
  <KeyCount>2</KeyCount>
  <MaxKeys>1000</MaxKeys>
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>prod/minimal.txt</Key>
  </Contents>
  <Contents>
    <Key>prod/full.txt</Key>
    <Size>42</Size>
    <LastModified>2025-12-01T10:30:00.000Z</LastModified>
  </Contents>
</ListBucketResult>`;

describe("parseListObjectsV2Response — missing fields", () => {
  it("defaults Size to 0 and LastModified to epoch when missing", () => {
    const result = parseListObjectsV2Response(MISSING_FIELDS_XML);

    assert.equal(result.objects.length, 2);
    // Minimal object: no Size, no LastModified
    assert.equal(result.objects[0].key, "prod/minimal.txt");
    assert.equal(result.objects[0].size, 0);
    assert.equal(
      result.objects[0].lastModified.toISOString(),
      "1970-01-01T00:00:00.000Z",
    );
    // Full object: has all fields
    assert.equal(result.objects[1].key, "prod/full.txt");
    assert.equal(result.objects[1].size, 42);
    assert.equal(
      result.objects[1].lastModified.toISOString(),
      "2025-12-01T10:30:00.000Z",
    );
  });
});

// ── listAllObjects tests ───────────────────────────────────────────────────

describe("listAllObjects", () => {
  let originalFetch: typeof globalThis.fetch;

  beforeEach(() => {
    originalFetch = globalThis.fetch;
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
    mock.reset();
  });

  it("returns all objects from a single page (sorted)", async () => {
    globalThis.fetch = mock.fn(() =>
      Promise.resolve(new Response(REAL_XML_RESPONSE, { status: 200 })),
    ) as unknown as typeof fetch;

    const result = await listAllObjects(TEST_CONFIG, { prefix: "prod/" });

    assert.equal(result.length, 3);
    // Sorted by size desc: 1048576 > 32768 > 512
    assert.equal(result[0].key, "prod/db.sqlite3");
    assert.equal(result[0].size, 1048576);
    assert.equal(result[1].key, "prod/db.sqlite3-shm");
    assert.equal(result[1].size, 32768);
    assert.equal(result[2].key, "prod/db.sqlite3-wal");
    assert.equal(result[2].size, 512);
  });

  it("sorts by size descending, then key descending", async () => {
    // Test data: prod/a (512), prod/b (2048), prod/c (512)
    const SORT_XML = `<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <IsTruncated>false</IsTruncated>
  <Contents><Key>prod/a.sqlite3</Key><Size>512</Size><LastModified>2025-01-01T00:00:00.000Z</LastModified></Contents>
  <Contents><Key>prod/b.sqlite3</Key><Size>2048</Size><LastModified>2025-01-01T00:00:00.000Z</LastModified></Contents>
  <Contents><Key>prod/c.sqlite3</Key><Size>512</Size><LastModified>2025-01-01T00:00:00.000Z</LastModified></Contents>
</ListBucketResult>`;

    globalThis.fetch = mock.fn(() =>
      Promise.resolve(new Response(SORT_XML, { status: 200 })),
    ) as unknown as typeof fetch;

    const result = await listAllObjects(TEST_CONFIG, { prefix: "prod/" });

    assert.equal(result.length, 3);
    // Largest first
    assert.equal(result[0].key, "prod/b.sqlite3");
    assert.equal(result[0].size, 2048);
    // Same size: alphabetically descending
    assert.equal(result[1].key, "prod/c.sqlite3");
    assert.equal(result[1].size, 512);
    assert.equal(result[2].key, "prod/a.sqlite3");
    assert.equal(result[2].size, 512);
  });

  it("aggregates objects across multiple pages", async () => {
    const PAGE1_XML = `<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <IsTruncated>true</IsTruncated>
  <NextContinuationToken>page2-token</NextContinuationToken>
  <Contents><Key>prod/obj1.sqlite3</Key><Size>100</Size><LastModified>2025-01-01T00:00:00.000Z</LastModified></Contents>
  <Contents><Key>prod/obj2.sqlite3</Key><Size>200</Size><LastModified>2025-01-01T00:00:00.000Z</LastModified></Contents>
</ListBucketResult>`;

    const PAGE2_XML = `<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <IsTruncated>false</IsTruncated>
  <Contents><Key>prod/obj3.sqlite3</Key><Size>300</Size><LastModified>2025-01-01T00:00:00.000Z</LastModified></Contents>
</ListBucketResult>`;

    let callCount = 0;
    globalThis.fetch = mock.fn(() => {
      callCount++;
      const xml = callCount === 1 ? PAGE1_XML : PAGE2_XML;
      return Promise.resolve(new Response(xml, { status: 200 }));
    }) as unknown as typeof fetch;

    const result = await listAllObjects(TEST_CONFIG, { prefix: "prod/" });

    assert.equal(result.length, 3);
    assert.equal(callCount, 2);
    // Sorted: 300 (obj3), 200 (obj2), 100 (obj1)
    assert.equal(result[0].key, "prod/obj3.sqlite3");
    assert.equal(result[0].size, 300);
    assert.equal(result[1].key, "prod/obj2.sqlite3");
    assert.equal(result[1].size, 200);
    assert.equal(result[2].key, "prod/obj1.sqlite3");
    assert.equal(result[2].size, 100);
  });

  it("passes continuation-token on subsequent pages", async () => {
    const PAGE1_XML = `<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <IsTruncated>true</IsTruncated>
  <NextContinuationToken>ct-token-xyz</NextContinuationToken>
  <Contents><Key>prod/a.sqlite3</Key><Size>1</Size><LastModified>2025-01-01T00:00:00.000Z</LastModified></Contents>
</ListBucketResult>`;

    const PAGE2_XML = `<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <IsTruncated>false</IsTruncated>
  <Contents><Key>prod/b.sqlite3</Key><Size>2</Size><LastModified>2025-01-01T00:00:00.000Z</LastModified></Contents>
</ListBucketResult>`;

    const urls: string[] = [];
    let callCount = 0;
    globalThis.fetch = mock.fn((url: string) => {
      urls.push(url);
      callCount++;
      const xml = callCount === 1 ? PAGE1_XML : PAGE2_XML;
      return Promise.resolve(new Response(xml, { status: 200 }));
    }) as unknown as typeof fetch;

    await listAllObjects(TEST_CONFIG, { prefix: "prod/" });

    assert.equal(callCount, 2);
    // First call: no continuation token
    assert.ok(!urls[0].includes("continuation-token"));
    // Second call: includes the continuation token from page 1
    assert.ok(urls[1].includes("continuation-token=ct-token-xyz"));
  });

  it("returns empty array for empty bucket", async () => {
    globalThis.fetch = mock.fn(() =>
      Promise.resolve(new Response(EMPTY_RESPONSE, { status: 200 })),
    ) as unknown as typeof fetch;

    const result = await listAllObjects(TEST_CONFIG, { prefix: "empty/" });

    assert.equal(result.length, 0);
  });

  it("propagates AbortError from fetch abort", async () => {
    const controller = new AbortController();

    globalThis.fetch = mock.fn(() => {
      const err = new DOMException("The operation was aborted", "AbortError");
      return Promise.reject(err);
    }) as unknown as typeof fetch;

    await assert.rejects(
      () => listAllObjects(TEST_CONFIG, { prefix: "prod/" }, controller.signal),
      AbortError,
    );
  });

  it("propagates NetworkError from fetch failure", async () => {
    globalThis.fetch = mock.fn(() =>
      Promise.reject(new TypeError("fetch failed")),
    ) as unknown as typeof fetch;

    await assert.rejects(
      () => listAllObjects(TEST_CONFIG, { prefix: "prod/" }),
      NetworkError,
    );
  });
});
