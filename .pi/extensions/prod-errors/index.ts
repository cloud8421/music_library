/**
 * Production Error Tools
 *
 * Fetches and displays production error data from the /api/v1/errors JSON API.
 *
 * Credentials are read from environment variables:
 *   PI_API_TOKEN         — Bearer token for API auth
 *   PI_SERVICE_FQDN_WEB  — Production domain (e.g., https://musiclibrary.example.com)
 *
 * Tools:
 *   fetch_production_errors — List/filter errors with pagination
 *   fetch_production_error  — Single error detail with occurrences and stacktraces
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import {
  truncateTail,
  formatSize,
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
} from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";

// ── Types ───────────────────────────────────────────────────────────────────

interface ErrorListItem {
  id: number;
  kind: string;
  reason: string;
  source_line: string;
  source_function: string;
  status: string;
  fingerprint: string;
  last_occurrence_at: string;
  muted: boolean;
  inserted_at: string;
  updated_at: string;
}

interface ErrorListResponse {
  errors: ErrorListItem[];
  total: number;
  limit: number;
  offset: number;
}

interface StacktraceLine {
  application: string;
  module: string;
  function: string;
  arity: number;
  file: string;
  line: number;
}

interface Occurrence {
  id: number;
  reason: string;
  context: Record<string, unknown>;
  breadcrumbs: string[];
  stacktrace: { lines: StacktraceLine[] };
  error_id: number;
  inserted_at: string;
}

interface ErrorDetail {
  id: number;
  kind: string;
  reason: string;
  source_line: string;
  source_function: string;
  status: string;
  fingerprint: string;
  last_occurrence_at: string;
  muted: boolean;
  inserted_at: string;
  updated_at: string;
  occurrence_count: number;
  first_occurrence_at: string | null;
  occurrences: Occurrence[];
}

interface ErrorDetailResponse {
  error: ErrorDetail;
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function resolveVar(name: string): string | undefined {
  return process.env[`PI_${name.toUpperCase()}`];
}

function buildUrl(
  base: string,
  path: string,
  params?: Record<string, string>,
): string {
  // Strip trailing slash and ensure protocol
  let url = base.replace(/\/+$/, "");
  if (!/^https?:\/\//i.test(url)) {
    url = `https://${url}`;
  }
  url = `${url}${path}`;

  if (params) {
    const searchParams = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== null) {
        searchParams.set(key, value);
      }
    }
    const qs = searchParams.toString();
    if (qs) {
      url = `${url}?${qs}`;
    }
  }

  return url;
}

// ── Formatting ──────────────────────────────────────────────────────────────

function formatErrorListItem(error: ErrorListItem, index: number): string {
  const mutedLabel = error.muted ? " [MUTED]" : "";
  return [
    `#${index} [${error.status}]${mutedLabel} ${error.kind}: ${error.reason}`,
    `   Source: ${error.source_line} — ${error.source_function}`,
    `   Last occurrence: ${error.last_occurrence_at}`,
    `   Fingerprint: ${error.fingerprint}`,
    `   ID: ${error.id}`,
  ].join("\n");
}

function formatErrorDetail(error: ErrorDetail): string {
  const lines: string[] = [];
  const sep = "─".repeat(44);

  lines.push(`Error #${error.id}: ${error.kind}`);
  lines.push(sep);
  lines.push(`Reason: ${error.reason}`);
  lines.push(`Status: ${error.status} | Muted: ${error.muted}`);
  lines.push(`Source: ${error.source_line} — ${error.source_function}`);
  lines.push(`Fingerprint: ${error.fingerprint}`);
  lines.push(`First occurrence: ${error.first_occurrence_at ?? "N/A"}`);
  lines.push(`Last occurrence: ${error.last_occurrence_at}`);
  lines.push(`Total occurrences: ${error.occurrence_count}`);
  lines.push(`Created: ${error.inserted_at} | Updated: ${error.updated_at}`);

  const occurrences = error.occurrences ?? [];
  lines.push("");
  lines.push(`Occurrences (${occurrences.length}):`);
  lines.push(sep);

  for (let i = 0; i < occurrences.length; i++) {
    const occ = occurrences[i];
    lines.push(`#${i + 1} ${occ.inserted_at}`);
    lines.push(`   Reason: ${occ.reason}`);

    // Context as key-value pairs
    if (occ.context && Object.keys(occ.context).length > 0) {
      const ctxLines = Object.entries(occ.context).map(
        ([k, v]) => `     ${k}: ${JSON.stringify(v)}`,
      );
      lines.push(`   Context:`);
      lines.push(...ctxLines);
    }

    // Breadcrumbs as bullet list
    if (occ.breadcrumbs && occ.breadcrumbs.length > 0) {
      lines.push(`   Breadcrumbs:`);
      for (const crumb of occ.breadcrumbs) {
        lines.push(`     • ${crumb}`);
      }
    }

    // Stacktrace
    if (occ.stacktrace?.lines && occ.stacktrace.lines.length > 0) {
      lines.push(`   Stacktrace:`);
      for (const sl of occ.stacktrace.lines) {
        const app = sl.application || "—";
        const loc = sl.file
          ? `${sl.file}${sl.line != null ? `:${sl.line}` : ""}`
          : "(nofile)";
        lines.push(
          `     ${app} / ${sl.module}.${sl.function}/${sl.arity}  ${loc}`,
        );
      }
    }

    if (i < occurrences.length - 1) {
      lines.push("");
    }
  }

  return lines.join("\n");
}

function applyOutputTruncation(output: string): string {
  const truncation = truncateTail(output, {
    maxLines: DEFAULT_MAX_LINES,
    maxBytes: DEFAULT_MAX_BYTES,
  });

  if (truncation.truncated) {
    return (
      truncation.content +
      `\n\n[Output truncated: ${truncation.outputLines} of ${truncation.totalLines} lines ` +
      `(${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)}). ` +
      `Use narrower filters to reduce output.]`
    );
  }

  return truncation.content;
}

// ── HTTP helpers ────────────────────────────────────────────────────────────

async function fetchErrors(
  url: string,
  token: string,
  signal?: AbortSignal,
): Promise<ErrorListResponse> {
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
    signal,
  });

  if (!response.ok) {
    const body = await response.text().catch(() => "(unable to read body)");
    const truncated = body.length > 500 ? body.slice(0, 500) + "..." : body;
    throw new Error(
      `API returned ${response.status} ${response.statusText}\n${truncated}`,
    );
  }

  let data: unknown;
  try {
    data = await response.json();
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    throw new Error(
      `Failed to parse API response: ${message}. Status: ${response.status}.`,
    );
  }

  const obj = data as Record<string, unknown>;
  if (!obj.errors || !Array.isArray(obj.errors)) {
    throw new Error(
      `Unexpected API response: 'errors' field is missing or not an array. Got: ${
        obj.errors === null ? "null" : typeof obj.errors
      }.`,
    );
  }

  return data as ErrorListResponse;
}

async function fetchError(
  url: string,
  token: string,
  signal?: AbortSignal,
): Promise<ErrorDetailResponse> {
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
    signal,
  });

  if (!response.ok) {
    const body = await response.text().catch(() => "(unable to read body)");
    const truncated = body.length > 500 ? body.slice(0, 500) + "..." : body;
    throw new Error(
      `API returned ${response.status} ${response.statusText}\n${truncated}`,
    );
  }

  let data: unknown;
  try {
    data = await response.json();
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    throw new Error(
      `Failed to parse API response: ${message}. Status: ${response.status}.`,
    );
  }

  const obj = data as Record<string, unknown>;
  if (!obj.error || typeof obj.error !== "object") {
    throw new Error(
      `Unexpected API response: 'error' field is missing or not an object. Got: ${
        obj.error === null ? "null" : typeof obj.error
      }.`,
    );
  }

  return data as ErrorDetailResponse;
}

// ── Extension ───────────────────────────────────────────────────────────────

export default function prodErrorsExtension(pi: ExtensionAPI) {
  // ── fetch_production_errors tool ───────────────────────────────────────

  pi.registerTool({
    name: "fetch_production_errors",
    label: "Fetch Production Errors",
    description:
      "Fetch production errors from the deployed application via the /api/v1/errors JSON API. " +
      "Use this tool when investigating what errors are occurring in production, " +
      "checking error frequency, browsing unresolved errors, or when the user asks " +
      "about production errors. Supports filtering by status, muted state, and " +
      "substring search on error reason. Output is truncated at 50KB / 2000 lines " +
      "— use narrower filters to reduce output if truncation occurs.",
    promptSnippet:
      "Fetch recent production errors from the errors API (params: status, muted, search, limit, offset)",
    promptGuidelines: [
      "Use fetch_production_errors when investigating what errors are occurring in production, checking error frequency, or browsing unresolved errors.",
      "Start with a small limit (e.g., 20) and filter by status or search before fetching large result sets. Use the 'search' parameter to find errors matching a specific reason or module.",
      "Use fetch_production_error when you need full details on a specific error, including stacktraces and context. Get the error ID from fetch_production_errors first.",
    ],
    parameters: Type.Object({
      status: Type.Optional(
        Type.Union([Type.Literal("resolved"), Type.Literal("unresolved")], {
          description:
            "Filter by error status: 'resolved' or 'unresolved'.",
        }),
      ),
      muted: Type.Optional(
        Type.Boolean({
          description: "Filter by muted state. true = only muted, false = only unmuted.",
        }),
      ),
      search: Type.Optional(
        Type.String({
          description:
            "Substring match on error reason. Case-insensitive search to find specific errors.",
        }),
      ),
      limit: Type.Optional(
        Type.Number({
          description:
            "Maximum number of errors to return. Default: 50. Use a smaller value to reduce output size.",
        }),
      ),
      offset: Type.Optional(
        Type.Number({
          description:
            "Pagination offset. Number of errors to skip. Default: 0.",
        }),
      ),
    }),
    async execute(
      _toolCallId,
      params,
      signal,
      _onUpdate,
      _ctx,
    ) {
      // Early abort check
      if (signal?.aborted) {
        return { content: [{ type: "text", text: "Cancelled" }] };
      }

      // Validate credentials
      const token = resolveVar("api_token");
      const fqdn = resolveVar("service_fqdn_web");

      const missing: string[] = [];
      if (!token) missing.push("PI_API_TOKEN");
      if (!fqdn) missing.push("PI_SERVICE_FQDN_WEB");

      if (missing.length > 0) {
        return {
          content: [
            {
              type: "text",
              text:
                `Cannot fetch production errors: the following environment variables are not set:\n` +
                missing.map((v) => `  - ${v}`).join("\n") +
                `\n\nEnsure these are configured in your pi environment.`,
            },
          ],
          isError: true,
        };
      }

      // Build query params for non-nil values
      const queryParams: Record<string, string> = {};
      if (params.status !== undefined && params.status !== null) {
        queryParams.status = params.status;
      }
      if (params.muted !== undefined && params.muted !== null) {
        queryParams.muted = String(params.muted);
      }
      if (params.search !== undefined && params.search !== null && params.search !== "") {
        queryParams.search = params.search;
      }
      if (params.limit !== undefined && params.limit !== null) {
        queryParams.limit = String(params.limit);
      }
      if (params.offset !== undefined && params.offset !== null) {
        queryParams.offset = String(params.offset);
      }

      const url = buildUrl(fqdn!, "/api/v1/errors", queryParams);

      // Fetch
      let data: ErrorListResponse;
      try {
        data = await fetchErrors(url, token!, signal);
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        return {
          content: [
            {
              type: "text",
              text: `Failed to fetch production errors: ${message}`,
            },
          ],
          isError: true,
        };
      }

      // Handle empty results
      if (data.errors.length === 0) {
        return {
          content: [{ type: "text", text: "No errors found matching the given filters." }],
          details: { total: data.total, count: 0, offset: data.offset, limit: data.limit },
        };
      }

      // Format output
      const count = data.errors.length;
      const from = (data.offset ?? 0) + 1;
      const to = (data.offset ?? 0) + count;

      const header = `Production Errors (total: ${data.total}, showing ${from}-${to})\n`;
      const body = data.errors
        .map((e, i) => formatErrorListItem(e, from + i))
        .join("\n\n");

      const output = applyOutputTruncation(header + body);

      return {
        content: [{ type: "text", text: output }],
        details: {
          total: data.total,
          count,
          offset: data.offset,
          limit: data.limit,
        },
      };
    },
  });

  // ── fetch_production_error tool ────────────────────────────────────────

  pi.registerTool({
    name: "fetch_production_error",
    label: "Fetch Production Error Detail",
    description:
      "Fetch full details for a specific production error by ID, including all " +
      "occurrences, stacktraces, context, and breadcrumbs. Use this tool when you " +
      "need to investigate a specific error in depth. Get the error ID from " +
      "fetch_production_errors first. Output is truncated at 50KB / 2000 lines.",
    promptSnippet:
      "Fetch full details for a specific production error by ID (param: id)",
    promptGuidelines: [
      "Use fetch_production_error when you need full details on a specific error, including stacktraces, context, and breadcrumbs from every occurrence.",
      "Get the error ID from fetch_production_errors first. Pass it as the 'id' parameter. The output includes all occurrences and may be large — review it carefully before asking for more.",
    ],
    parameters: Type.Object({
      id: Type.Number({
        description:
          "The error ID (integer) to fetch full details for. Get this from fetch_production_errors.",
      }),
    }),
    async execute(
      _toolCallId,
      params,
      signal,
      _onUpdate,
      _ctx,
    ) {
      // Early abort check
      if (signal?.aborted) {
        return { content: [{ type: "text", text: "Cancelled" }] };
      }

      // Validate credentials
      const token = resolveVar("api_token");
      const fqdn = resolveVar("service_fqdn_web");

      const missing: string[] = [];
      if (!token) missing.push("PI_API_TOKEN");
      if (!fqdn) missing.push("PI_SERVICE_FQDN_WEB");

      if (missing.length > 0) {
        return {
          content: [
            {
              type: "text",
              text:
                `Cannot fetch production error: the following environment variables are not set:\n` +
                missing.map((v) => `  - ${v}`).join("\n") +
                `\n\nEnsure these are configured in your pi environment.`,
            },
          ],
          isError: true,
        };
      }

      const url = buildUrl(fqdn!, `/api/v1/errors/${params.id}`);

      // Fetch
      let data: ErrorDetailResponse;
      try {
        data = await fetchError(url, token!, signal);
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        // Check if it looks like a 404
        if (message.includes("404")) {
          return {
            content: [
              {
                type: "text",
                text: `Error with ID ${params.id} not found.`,
              },
            ],
            isError: true,
          };
        }
        return {
          content: [
            {
              type: "text",
              text: `Failed to fetch production error: ${message}`,
            },
          ],
          isError: true,
        };
      }

      // Format output
      const output = applyOutputTruncation(formatErrorDetail(data.error));

      return {
        content: [{ type: "text", text: output }],
        details: {
          errorId: params.id,
          occurrenceCount: data.error.occurrence_count,
        },
      };
    },
  });
}
