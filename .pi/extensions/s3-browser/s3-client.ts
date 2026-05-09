/**
 * Minimal S3 client using aws4 for SigV4 signing and Node.js built-in fetch.
 *
 * Only ListObjectsV2 is implemented — the sole API operation needed by the
 * s3-browser pi extension.
 *
 * Dependency surface: aws4 (single-file, 0 transitive deps) + Node.js built-ins.
 */

import aws4 from "aws4";

// ── Types ───────────────────────────────────────────────────────────────────

export interface S3ClientConfig {
  /** S3 endpoint hostname (no protocol), e.g. "nbg1.your-objectstorage.com" */
  endpoint: string;
  /** S3 region, e.g. "nbg1" */
  region: string;
  /** Bucket name */
  bucket: string;
  /** Access key ID */
  accessKeyId: string;
  /** Secret access key */
  secretAccessKey: string;
}

export interface ListObjectsV2Params {
  /** Object key prefix */
  prefix?: string;
  /** Pagination continuation token */
  continuationToken?: string;
  /** Maximum keys per page (default: 1000) */
  maxKeys?: number;
}

export interface S3Object {
  key: string;
  size: number;
  lastModified: Date;
}

export interface ListObjectsV2Response {
  objects: S3Object[];
  isTruncated: boolean;
  nextContinuationToken?: string;
}

// ── Error types ─────────────────────────────────────────────────────────────

export class AuthError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AuthError";
  }
}

export class NotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "NotFoundError";
  }
}

export class NetworkError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "NetworkError";
  }
}

export class AbortError extends Error {
  constructor() {
    super("Request aborted");
    this.name = "AbortError";
  }
}

export class ServerError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ServerError";
  }
}

export type S3Error =
  | AuthError
  | NotFoundError
  | NetworkError
  | AbortError
  | ServerError;

// ── Signing ─────────────────────────────────────────────────────────────────

interface SignedRequest {
  url: string;
  headers: Record<string, string>;
}

/**
 * Sign an S3 GET request using aws4.
 *
 * aws4.sign() returns options shaped for Node.js http.request
 * ({host, path, headers}). We extract headers and construct the
 * full URL for use with fetch.
 */
export function signRequest(
  config: S3ClientConfig,
  pathAndQuery: string,
): SignedRequest {
  const opts = {
    host: config.endpoint,
    path: pathAndQuery,
    service: "s3",
    region: config.region,
    method: "GET",
    headers: {
      "X-Amz-Content-Sha256": "UNSIGNED-PAYLOAD",
      Host: config.endpoint,
    },
  };

  const signed = aws4.sign(opts, {
    accessKeyId: config.accessKeyId,
    secretAccessKey: config.secretAccessKey,
  });

  const url = `https://${signed.host}${signed.path}`;
  const headers: Record<string, string> = {};
  for (const [key, value] of Object.entries(signed.headers)) {
    headers[key.toLowerCase()] = String(value);
  }

  return { url, headers };
}

// ── XML parsing ─────────────────────────────────────────────────────────────

/** Escape regex metacharacters in a string so it can be used literally. */
function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Decode common XML character entities. */
function decodeXmlEntities(text: string): string {
  return text
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'");
}

/**
 * Extract text content between XML tags.
 * Handles namespace-qualified tags (e.g., <Contents xmlns="...">).
 */
function xmlText(xml: string, tag: string): string {
  const escaped = escapeRegex(tag);
  const re = new RegExp(`<${escaped}[^>]*>([\\s\\S]*?)<\\/${escaped}>`, "i");
  const match = xml.match(re);
  return match ? match[1].trim() : "";
}

/**
 * Parse a ListObjectsV2 XML response body into structured data.
 *
 * Uses regex-based extraction (no full XML parser needed) to handle
 * namespace-qualified XML that Hetzner Object Storage may return.
 */
export function parseListObjectsV2Response(xml: string): ListObjectsV2Response {
  const objects: S3Object[] = [];

  // Match <Contents> blocks, handling optional namespace attributes
  const contentsRe = /<Contents[^>]*>([\s\S]*?)<\/Contents>/gi;
  let match: RegExpExecArray | null;

  while ((match = contentsRe.exec(xml)) !== null) {
    const block = match[1];
    const key = xmlText(block, "Key");
    const size = xmlText(block, "Size");
    const lastModified = xmlText(block, "LastModified");

    if (key) {
      objects.push({
        key: decodeXmlEntities(key),
        size: size ? Number(size) : 0,
        lastModified: lastModified ? new Date(lastModified) : new Date(0),
      });
    }
  }

  const isTruncated = xmlText(xml, "IsTruncated") === "true";
  const nextContinuationToken =
    xmlText(xml, "NextContinuationToken") || undefined;

  return { objects, isTruncated, nextContinuationToken };
}

/**
 * Parse an S3 error XML response.
 */
export function parseErrorResponse(xml: string): {
  code: string;
  message: string;
} {
  return {
    code: xmlText(xml, "Code"),
    message: xmlText(xml, "Message"),
  };
}

// ── Paginated listing ───────────────────────────────────────────────────────

/**
 * Fetch all objects across all pages (handles ContinuationToken).
 *
 * Results are sorted by size descending, then key descending — matching
 * the display order the s3-browser extension uses.
 */
export async function listAllObjects(
  config: S3ClientConfig,
  params: Omit<ListObjectsV2Params, "continuationToken">,
  signal?: AbortSignal,
): Promise<S3Object[]> {
  const results: S3Object[] = [];
  let continuationToken: string | undefined;

  do {
    const response = await listObjectsV2(
      config,
      { ...params, continuationToken },
      signal,
    );

    results.push(...response.objects);

    continuationToken = response.isTruncated
      ? response.nextContinuationToken
      : undefined;
  } while (continuationToken);

  // Sort by size descending, then alphabetically descending
  results.sort((a, b) => {
    const sizeDiff = b.size - a.size;
    if (sizeDiff !== 0) return sizeDiff;
    return b.key.localeCompare(a.key);
  });
  return results;
}

// ── API call ────────────────────────────────────────────────────────────────

function buildPath(
  config: S3ClientConfig,
  params: ListObjectsV2Params,
): string {
  const query = new URLSearchParams();
  query.set("list-type", "2");

  if (params.prefix) query.set("prefix", params.prefix);
  if (params.continuationToken)
    query.set("continuation-token", params.continuationToken);
  if (params.maxKeys) query.set("max-keys", String(params.maxKeys));

  return `/${config.bucket}/?${query.toString()}`;
}

/**
 * Call S3 ListObjectsV2 with the given config, params, and optional AbortSignal.
 *
 * @throws {AuthError} On HTTP 401/403
 * @throws {NotFoundError} On HTTP 404
 * @throws {NetworkError} On fetch rejection (DNS, timeout, unreachable)
 * @throws {AbortError} On signal abort
 * @throws {ServerError} On HTTP 5xx or unexpected status
 */
export async function listObjectsV2(
  config: S3ClientConfig,
  params: ListObjectsV2Params,
  signal?: AbortSignal,
): Promise<ListObjectsV2Response> {
  const pathAndQuery = buildPath(config, params);
  const { url, headers } = signRequest(config, pathAndQuery);

  let response: Response;
  try {
    response = await fetch(url, { headers, signal });
  } catch (err: unknown) {
    if (err instanceof DOMException && err.name === "AbortError") {
      throw new AbortError();
    }
    // fetch can also throw TypeError for network failures
    throw new NetworkError(
      `Could not reach S3 endpoint: ${err instanceof Error ? err.message : String(err)}`,
    );
  }

  // Check for abort after fetch resolves (edge case)
  if (signal?.aborted) {
    throw new AbortError();
  }

  const text = await response.text();

  if (response.status === 401 || response.status === 403) {
    const err = parseErrorResponse(text);
    throw new AuthError(
      err.message || `Authentication failed (HTTP ${response.status})`,
    );
  }

  if (response.status === 404) {
    throw new NotFoundError(`Bucket or endpoint not found (HTTP 404)`);
  }

  if (response.status >= 500) {
    throw new ServerError(`S3 server error (HTTP ${response.status})`);
  }

  if (!response.ok) {
    throw new ServerError(`Unexpected HTTP ${response.status}`);
  }

  return parseListObjectsV2Response(text);
}
