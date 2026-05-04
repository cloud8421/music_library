/**
 * Production Error Tools & Browser
 *
 * Fetches and displays production error data from the /api/v1/errors JSON API.
 *
 * Credentials are read from environment variables:
 *   PI_API_TOKEN         — Bearer token for API auth
 *   PI_SERVICE_FQDN_WEB  — Production domain (e.g., https://musiclibrary.example.com)
 *
 * Tools:
 *   fetch_production_errors  — List/filter errors with pagination
 *   fetch_production_error   — Single error detail with occurrences and stacktraces
 *
 * Commands:
 *   /prod-errors  — Interactive TUI for browsing production errors
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import {
  truncateTail,
  formatSize,
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
} from "@mariozechner/pi-coding-agent";
import { BorderedLoader } from "@mariozechner/pi-coding-agent";
import {
  matchesKey,
  Key,
  truncateToWidth,
} from "@mariozechner/pi-tui";
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

// ── TUI Theme ───────────────────────────────────────────────────────────────

/** Minimal theme interface for color application in the ErrorBrowser. */
interface Theme {
  fg(color: string, text: string): string;
  bold(text: string): string;
}

// ── TUI Helpers ─────────────────────────────────────────────────────────────

function formatRelativeTime(iso8601: string): string {
  const then = new Date(iso8601).getTime();
  const now = Date.now();
  const diffSec = Math.floor((now - then) / 1000);

  if (diffSec < 60) return "just now";

  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `${diffMin}m ago`;

  const diffHour = Math.floor(diffMin / 60);
  if (diffHour < 24) return `${diffHour}h ago`;

  const diffDay = Math.floor(diffHour / 24);
  return `${diffDay}d ago`;
}

function truncateReason(reason: string, maxLen: number): string {
  // Take only the first line
  const firstLine = reason.split("\n")[0] ?? reason;
  if (firstLine.length <= maxLen) return firstLine;
  return firstLine.slice(0, maxLen - 1) + "…";
}

// ── Error Browser Component ─────────────────────────────────────────────────

class ErrorBrowser {
  // ── State ──────────────────────────────────────────────────────────────

  private mode: "list" | "detail" | "loading" = "list";
  private errors: ErrorListItem[];
  private total: number;
  private offset: number;
  private readonly limit: number = 50;
  private showResolved: boolean = true;
  private showMuted: boolean = true;
  private cursorIndex: number = 0;
  private scrollOffset: number = 0;
  private selectedError: ErrorDetail | null = null;
  private detailScrollOffset: number = 0;
  private readonly totalUnfiltered: number;
  private readonly chromeHeight: number = 7;
  private readonly errorEntryLines: number = 3;

  // ── Callbacks ──────────────────────────────────────────────────────────

  onClose?: () => void;
  onCopy?: (text: string) => void;

  // ── Caching ────────────────────────────────────────────────────────────

  private cachedWidth?: number;
  private cachedLines?: string[];

  // ── HTTP ───────────────────────────────────────────────────────────────

  private currentAbortController?: AbortController;
  private readonly baseUrl: string;
  private readonly token: string;
  private readonly requestRender: () => void;
  private readonly notify: (msg: string, level: "error" | "info" | "warning") => void;

  constructor(
    errors: ErrorListItem[],
    total: number,
    baseUrl: string,
    token: string,
    requestRender: () => void,
    notify: (msg: string, level: "error" | "info" | "warning") => void,
  ) {
    this.errors = errors;
    this.total = total;
    this.totalUnfiltered = total;
    this.offset = 0;
    this.baseUrl = baseUrl;
    this.token = token;
    this.requestRender = requestRender;
    this.notify = notify;
    this.clampCursor();
  }

  // ── Viewport ───────────────────────────────────────────────────────────

  private get visibleHeight(): number {
    return Math.max(10, process.stdout.rows - this.chromeHeight);
  }

  // ── Navigation helpers ─────────────────────────────────────────────────

  private clampCursor(): void {
    if (this.errors.length === 0) {
      this.cursorIndex = -1;
    } else {
      this.cursorIndex = Math.max(0, Math.min(this.cursorIndex, this.errors.length - 1));
    }
  }

  private clampViewport(): void {
    if (this.errors.length === 0) return;
    const maxEntries = Math.floor(this.visibleHeight / this.errorEntryLines);
    if (this.cursorIndex < this.scrollOffset) {
      this.scrollOffset = this.cursorIndex;
    } else if (this.cursorIndex >= this.scrollOffset + maxEntries) {
      this.scrollOffset = this.cursorIndex - maxEntries + 1;
    }
    this.scrollOffset = Math.max(0, Math.min(this.scrollOffset, this.errors.length - 1));
  }

  // ── HTTP helpers ───────────────────────────────────────────────────────

  private abortInFlight(): void {
    if (this.currentAbortController) {
      this.currentAbortController.abort();
      this.currentAbortController = undefined;
    }
  }

  private buildQueryParams(): Record<string, string> {
    const params: Record<string, string> = {};
    if (!this.showResolved) params.status = "unresolved";
    if (!this.showMuted) params.muted = "false";
    params.limit = String(this.limit);
    params.offset = String(this.offset);
    return params;
  }

  // ── Async operations ───────────────────────────────────────────────────

  toggleResolved(): void {
    if (this.mode === "loading") return;
    this.abortInFlight();
    this.showResolved = !this.showResolved;
    this.offset = 0;
    this.cursorIndex = 0;
    this.scrollOffset = 0;
    this.mode = "loading";
    this.invalidate();
    this.requestRender();

    const url = buildUrl(this.baseUrl, "/api/v1/errors", this.buildQueryParams());
    const controller = new AbortController();
    this.currentAbortController = controller;

    fetchErrors(url, this.token, controller.signal)
      .then((data) => {
        this.errors = data.errors;
        this.total = data.total;
        this.offset = data.offset ?? 0;
        this.cursorIndex = 0;
        this.scrollOffset = 0;
        this.clampCursor();
        this.clampViewport();
        this.mode = "list";
        this.invalidate();
        this.requestRender();
      })
      .catch((err) => {
        if (err instanceof Error && err.name === "AbortError") return;
        this.mode = "list";
        const msg = err instanceof Error ? err.message : String(err);
        this.notify(`Filter toggle failed: ${msg}`, "error");
        this.invalidate();
        this.requestRender();
      });
  }

  toggleMuted(): void {
    if (this.mode === "loading") return;
    this.abortInFlight();
    this.showMuted = !this.showMuted;
    this.offset = 0;
    this.cursorIndex = 0;
    this.scrollOffset = 0;
    this.mode = "loading";
    this.invalidate();
    this.requestRender();

    const url = buildUrl(this.baseUrl, "/api/v1/errors", this.buildQueryParams());
    const controller = new AbortController();
    this.currentAbortController = controller;

    fetchErrors(url, this.token, controller.signal)
      .then((data) => {
        this.errors = data.errors;
        this.total = data.total;
        this.offset = data.offset ?? 0;
        this.cursorIndex = 0;
        this.scrollOffset = 0;
        this.clampCursor();
        this.clampViewport();
        this.mode = "list";
        this.invalidate();
        this.requestRender();
      })
      .catch((err) => {
        if (err instanceof Error && err.name === "AbortError") return;
        this.mode = "list";
        const msg = err instanceof Error ? err.message : String(err);
        this.notify(`Filter toggle failed: ${msg}`, "error");
        this.invalidate();
        this.requestRender();
      });
  }

  loadMore(): void {
    if (this.mode === "loading") return;
    if (this.offset + this.limit >= this.total) return; // end of results

    this.abortInFlight();
    this.offset = this.offset + this.limit;
    this.mode = "loading";
    this.invalidate();
    this.requestRender();

    const url = buildUrl(this.baseUrl, "/api/v1/errors", this.buildQueryParams());
    const controller = new AbortController();
    this.currentAbortController = controller;

    fetchErrors(url, this.token, controller.signal)
      .then((data) => {
        // Append new errors (deduplicate by id)
        const existingIds = new Set(this.errors.map((e) => e.id));
        const newErrors = data.errors.filter((e) => !existingIds.has(e.id));
        this.errors = [...this.errors, ...newErrors];
        this.total = data.total;
        // offset already incremented before fetch; keep it
        this.clampCursor();
        this.clampViewport();
        this.mode = "list";
        this.invalidate();
        this.requestRender();
      })
      .catch((err) => {
        if (err instanceof Error && err.name === "AbortError") return;
        // Revert offset on failure
        this.offset = this.offset - this.limit;
        this.mode = "list";
        const msg = err instanceof Error ? err.message : String(err);
        this.notify(`Load more failed: ${msg}`, "error");
        this.invalidate();
        this.requestRender();
      });
  }

  fetchDetail(id: number): void {
    if (this.mode === "loading") return;

    this.abortInFlight();
    this.mode = "loading";
    this.detailScrollOffset = 0;
    this.invalidate();
    this.requestRender();

    const url = buildUrl(this.baseUrl, `/api/v1/errors/${id}`);
    const controller = new AbortController();
    this.currentAbortController = controller;

    fetchError(url, this.token, controller.signal)
      .then((data) => {
        this.selectedError = data.error;
        this.detailScrollOffset = 0;
        this.mode = "detail";
        this.invalidate();
        this.requestRender();
      })
      .catch((err) => {
        if (err instanceof Error && err.name === "AbortError") return;
        this.mode = "list";
        const msg = err instanceof Error ? err.message : String(err);
        if (msg.includes("404")) {
          this.notify(`Error #${id} not found`, "warning");
        } else {
          this.notify(`Failed to load error detail: ${msg}`, "error");
        }
        this.invalidate();
        this.requestRender();
      });
  }

  // ── Input handling ─────────────────────────────────────────────────────

  handleInput(data: string): void {
    // Global keys (work in any mode)
    if (matchesKey(data, Key.escape)) {
      if (this.mode === "detail") {
        // Back to list
        this.mode = "list";
        this.selectedError = null;
        this.detailScrollOffset = 0;
        this.invalidate();
        return;
      }
      this.onClose?.();
      return;
    }

    if (matchesKey(data, "q")) {
      if (this.mode !== "detail") {
        this.onClose?.();
        return;
      }
    }

    // ── List mode keys ────────────────────────────────────────────────

    if (this.mode === "list" || this.mode === "loading") {
      if (matchesKey(data, "r")) {
        this.toggleResolved();
        return;
      }

      if (matchesKey(data, "m")) {
        this.toggleMuted();
        return;
      }

      if (matchesKey(data, "l")) {
        if (this.offset + this.limit >= this.total) return;
        this.loadMore();
        return;
      }

      if (matchesKey(data, Key.enter)) {
        if (this.errors.length > 0 && this.cursorIndex >= 0) {
          const error = this.errors[this.cursorIndex];
          if (error) {
            this.fetchDetail(error.id);
          }
        }
        return;
      }

      if (this.mode !== "list") return; // block navigation while loading

      let moved = false;

      if (matchesKey(data, Key.up) || matchesKey(data, "k")) {
        this.cursorIndex--;
        moved = true;
      } else if (matchesKey(data, Key.down) || matchesKey(data, "j")) {
        this.cursorIndex++;
        moved = true;
      } else if (matchesKey(data, Key.pageUp)) {
        const pageSize = Math.floor(this.visibleHeight / this.errorEntryLines);
        this.cursorIndex -= pageSize;
        moved = true;
      } else if (matchesKey(data, Key.pageDown) || matchesKey(data, Key.ctrl("f"))) {
        const pageSize = Math.floor(this.visibleHeight / this.errorEntryLines);
        this.cursorIndex += pageSize;
        moved = true;
      } else if (matchesKey(data, Key.ctrl("b"))) {
        const pageSize = Math.floor(this.visibleHeight / this.errorEntryLines);
        this.cursorIndex -= pageSize;
        moved = true;
      } else if (matchesKey(data, Key.home) || matchesKey(data, "g")) {
        this.cursorIndex = 0;
        moved = true;
      } else if (matchesKey(data, Key.end) || matchesKey(data, "G")) {
        this.cursorIndex = this.errors.length - 1;
        moved = true;
      }

      if (moved) {
        this.clampCursor();
        this.clampViewport();
        this.invalidate();
      }

      return;
    }

    // ── Detail mode keys ───────────────────────────────────────────────

    if (this.mode === "detail") {
      if (matchesKey(data, Key.enter)) {
        // Copy current line to editor (prod-logs pattern)
        if (this.selectedError) {
          const detailLines = this.buildDetailLines();
          const idx = this.detailScrollOffset;
          if (idx < detailLines.length) {
            this.onCopy?.(detailLines[idx]!);
          }
        }
        return;
      }

      let moved = false;

      if (matchesKey(data, Key.up) || matchesKey(data, "k")) {
        this.detailScrollOffset--;
        moved = true;
      } else if (matchesKey(data, Key.down) || matchesKey(data, "j")) {
        this.detailScrollOffset++;
        moved = true;
      } else if (matchesKey(data, Key.pageUp)) {
        this.detailScrollOffset -= this.visibleHeight;
        moved = true;
      } else if (matchesKey(data, Key.pageDown) || matchesKey(data, Key.ctrl("f"))) {
        this.detailScrollOffset += this.visibleHeight;
        moved = true;
      } else if (matchesKey(data, Key.ctrl("b"))) {
        this.detailScrollOffset -= this.visibleHeight;
        moved = true;
      } else if (matchesKey(data, Key.home) || matchesKey(data, "g")) {
        this.detailScrollOffset = 0;
        moved = true;
      } else if (matchesKey(data, Key.end) || matchesKey(data, "G")) {
        this.detailScrollOffset = Math.max(0, this.buildDetailLines().length - 1);
        moved = true;
      }

      if (moved) {
        this.detailScrollOffset = Math.max(
          0,
          Math.min(this.detailScrollOffset, Math.max(0, this.buildDetailLines().length - 1)),
        );
        this.invalidate();
      }

      return;
    }
  }

  // ── Rendering ──────────────────────────────────────────────────────────

  render(width: number, theme: Theme): string[] {
    if (this.cachedLines && this.cachedWidth === width) {
      return this.cachedLines;
    }

    let result: string[];
    switch (this.mode) {
      case "loading":
        result = this.renderLoading(width, theme);
        break;
      case "detail":
        result = this.renderDetail(width, theme);
        break;
      default:
        result = this.renderList(width, theme);
        break;
    }

    this.cachedWidth = width;
    this.cachedLines = result;
    return result;
  }

  private renderLoading(width: number, theme: Theme): string[] {
    const border = theme.fg("accent", "─".repeat(width));
    const rows = process.stdout.rows;
    const result: string[] = [border];
    const mid = Math.floor((rows - 1) / 2);

    for (let i = 1; i < rows - 1; i++) {
      if (i === mid) {
        result.push(truncateToWidth(theme.fg("muted", "  Loading…"), width, ""));
      } else {
        result.push("");
      }
    }

    result.push(border);
    return result;
  }

  private renderList(width: number, theme: Theme): string[] {
    const border = theme.fg("accent", "─".repeat(width));
    const result: string[] = [];

    // Top border
    result.push(border);

    // Header with counts
    const unresolvedCount = this.errors.filter(
      (e) => e.status === "unresolved",
    ).length;
    const headerText = ` Production Errors (${this.total} total${unresolvedCount > 0 ? `, ${unresolvedCount} unresolved` : ""})`;
    result.push(
      truncateToWidth(theme.fg("accent", theme.bold(headerText)), width, ""),
    );

    // Divider
    result.push(truncateToWidth(theme.fg("dim", "─".repeat(width)), width, ""));

    // Empty states
    if (this.errors.length === 0) {
      const msg =
        this.totalUnfiltered > 0
          ? "No errors match the current filters"
          : "No production errors found";
      result.push(truncateToWidth(theme.fg("muted", `  ${msg}`), width, ""));
      // Pad remaining viewport
      while (result.length < this.visibleHeight + 3) {
        result.push("");
      }
    } else {
      // Render errors within viewport
      const maxEntries = Math.floor(this.visibleHeight / this.errorEntryLines);
      const endIdx = Math.min(
        this.scrollOffset + maxEntries,
        this.errors.length,
      );

      let linesRendered = 0;
      for (let i = this.scrollOffset; i < endIdx; i++) {
        const error = this.errors[i];
        if (!error) continue;

        const isCursor = i === this.cursorIndex;
        const cursor = isCursor ? "▶" : " ";

        // Status badge color
        let statusColor = "muted";
        if (error.status === "unresolved") statusColor = "error";
        else if (error.status === "resolved") statusColor = "success";

        const mutedLabel = error.muted ? " [MUTED]" : "";
        const statusBadge = theme.fg(statusColor, `[${error.status.toUpperCase()}]`);

        // Line 1: cursor + status badge + kind + truncated reason
        const reasonText = truncateReason(error.reason, Math.max(30, width - 25));
        const line1 = `${cursor} ${statusBadge}${mutedLabel} ${error.kind}: ${reasonText}`;
        result.push(truncateToWidth(isCursor ? theme.fg("accent", line1) : line1, width, ""));

        // Line 2: source info
        const sourceInfo = error.source_function
          ? `  ${error.source_function}  ${error.source_line || ""}`
          : `  ${error.source_line || "(no source)"}`;
        result.push(truncateToWidth(theme.fg("dim", sourceInfo), width, ""));

        // Line 3: last seen relative time
        const lastSeen = error.last_occurrence_at
          ? `  Last seen ${formatRelativeTime(error.last_occurrence_at)}`
          : "  No occurrences";
        result.push(truncateToWidth(theme.fg("dim", lastSeen), width, ""));

        linesRendered += this.errorEntryLines;
      }

      // Pad remaining viewport if fewer lines than visible
      const targetLines = 3 + this.visibleHeight;
      while (result.length < targetLines) {
        result.push("");
      }
    }

    // Help lines
    const resolvedLabel = this.showResolved ? "hide" : "show";
    const mutedLabel = this.showMuted ? "hide" : "show";
    const hasMore = this.offset + this.limit < this.total;

    result.push(
      truncateToWidth(
        theme.fg(
          "dim",
          ` ↑↓/jk navigate  ↵ details  r ${resolvedLabel} resolved  m ${mutedLabel} muted`,
        ),
        width,
        "",
      ),
    );
    result.push(
      truncateToWidth(
        theme.fg(
          "dim",
          hasMore
            ? ` l load more  q quit`
            : ` — end of results —  q quit`,
        ),
        width,
        "",
      ),
    );

    // Bottom border
    result.push(border);

    return result;
  }

  private buildDetailLines(): string[] {
    const error = this.selectedError;
    if (!error) return ["(no error selected)"];

    const lines: string[] = [];
    const sep = "─".repeat(40);

    lines.push(`Error #${error.id}: ${error.kind}`);
    lines.push(sep);
    lines.push(`Reason: ${error.reason}`);
    lines.push(`Status: ${error.status} | Muted: ${error.muted}`);
    lines.push(
      `Source: ${error.source_line || "—"} — ${error.source_function || "—"}`,
    );
    lines.push(`Fingerprint: ${error.fingerprint || "—"}`);
    lines.push(`First occurrence: ${error.first_occurrence_at ?? "N/A"}`);
    lines.push(`Last occurrence: ${error.last_occurrence_at}`);
    lines.push(`Total occurrences: ${error.occurrence_count}`);
    lines.push("");

    const occurrences = error.occurrences ?? [];
    lines.push(`Occurrences (${occurrences.length}):`);
    lines.push(sep);

    if (occurrences.length === 0) {
      lines.push("  No occurrences recorded");
    } else {
      for (let i = 0; i < occurrences.length; i++) {
        const occ = occurrences[i]!;
        lines.push(`#${i + 1} ${occ.inserted_at}`);
        lines.push(`   Reason: ${occ.reason}`);

        if (occ.context && Object.keys(occ.context).length > 0) {
          lines.push(`   Context:`);
          for (const [k, v] of Object.entries(occ.context)) {
            lines.push(`     ${k}: ${JSON.stringify(v)}`);
          }
        }

        if (occ.breadcrumbs && occ.breadcrumbs.length > 0) {
          lines.push(`   Breadcrumbs:`);
          for (const crumb of occ.breadcrumbs) {
            lines.push(`     • ${crumb}`);
          }
        }

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
    }

    return lines;
  }

  private renderDetail(width: number, theme: Theme): string[] {
    const border = theme.fg("accent", "─".repeat(width));
    const result: string[] = [];

    // Top border
    result.push(border);

    // Header
    const error = this.selectedError;
    const headerText = error
      ? ` Error #${error.id}: ${error.kind}`
      : " Error Detail";
    result.push(
      truncateToWidth(theme.fg("accent", theme.bold(headerText)), width, ""),
    );

    // Divider
    result.push(truncateToWidth(theme.fg("dim", "─".repeat(width)), width, ""));

    // Detail content (scrolled)
    const detailLines = this.buildDetailLines();
    const endIdx = Math.min(
      this.detailScrollOffset + this.visibleHeight,
      detailLines.length,
    );

    for (let i = this.detailScrollOffset; i < endIdx; i++) {
      result.push(truncateToWidth(`  ${detailLines[i]}`, width, ""));
    }

    // Pad remaining viewport
    const targetLines = 3 + this.visibleHeight;
    while (result.length < targetLines) {
      result.push("");
    }

    // Help line
    const fromLine = this.detailScrollOffset + 1;
    const toLine = Math.min(
      this.detailScrollOffset + this.visibleHeight,
      detailLines.length,
    );
    const pct =
      detailLines.length > 0
        ? Math.round((this.detailScrollOffset / detailLines.length) * 100)
        : 0;
    result.push(
      truncateToWidth(
        theme.fg(
          "dim",
          ` Lines ${fromLine}-${toLine} of ${detailLines.length} (${pct}%)  ↑↓/jk scroll  Enter copy  Escape back`,
        ),
        width,
        "",
      ),
    );

    // Bottom border
    result.push(border);

    return result;
  }

  invalidate(): void {
    this.cachedWidth = undefined;
    this.cachedLines = undefined;
  }
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

  // ── /prod-errors interactive command ──────────────────────────────────

  pi.registerCommand("prod-errors", {
    description:
      "Browse production errors interactively via the /api/v1/errors JSON API",
    handler: async (_args, ctx) => {
      // ── Validate credentials ────────────────────────────────────────

      const token = resolveVar("api_token");
      const fqdn = resolveVar("service_fqdn_web");

      const missing: string[] = [];
      if (!token) missing.push("PI_API_TOKEN");
      if (!fqdn) missing.push("PI_SERVICE_FQDN_WEB");

      if (missing.length > 0) {
        ctx.ui.notify(
          `Missing environment variables: ${missing.join(", ")}`,
          "error",
        );
        return;
      }

      // ── Fetch initial errors with loader UI ─────────────────────────

      const errorsData = await ctx.ui.custom<ErrorListResponse | null>(
        (tui, theme, _kb, done) => {
          const loader = new BorderedLoader(
            tui,
            theme,
            "Fetching production errors...",
          );
          loader.onAbort = () => done(null);

          const url = buildUrl(fqdn!, "/api/v1/errors", {
            limit: "50",
            offset: "0",
          });

          fetchErrors(url, token!, loader.signal)
            .then(done)
            .catch((err) => {
              console.error("[prod-errors] Initial fetch failed:", err);
              done(null);
            });

          return loader;
        },
      );

      if (errorsData === null) {
        ctx.ui.notify("Cancelled or fetch failed — check logs for details", "info");
        return;
      }

      if (errorsData.errors.length === 0) {
        ctx.ui.notify("No production errors found", "info");
        return;
      }

      // ── Interactive error browser ────────────────────────────────────

      const baseUrl = fqdn!;
      const apiToken = token!;

      const copiedText = await ctx.ui.custom<string | null>(
        (tui, theme, _kb, done) => {
          const browser = new ErrorBrowser(
            errorsData.errors,
            errorsData.total,
            baseUrl,
            apiToken,
            () => tui.requestRender(),
            (msg, level) => ctx.ui.notify(msg, level),
          );

          browser.onClose = () => done(null);
          browser.onCopy = (text: string) => done(text);

          return {
            render(width: number) {
              return browser.render(width, theme);
            },
            invalidate() {
              browser.invalidate();
            },
            handleInput(data: string) {
              browser.handleInput(data);
              tui.requestRender();
            },
          };
        },
      );

      // ── Place copied text in editor ──────────────────────────────────

      if (copiedText !== null) {
        ctx.ui.setEditorText(copiedText);
      }

      ctx.ui.notify("Error browser closed", "info");
    },
  });
}
