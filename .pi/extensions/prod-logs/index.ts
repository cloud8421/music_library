/**
 * Production Log Viewer
 *
 * Fetches and displays application logs from the Coolify API.
 *
 * Credentials are read from environment variables:
 *   PI_COOLIFY_HOST
 *   PI_COOLIFY_APP_UUID
 *   PI_COOLIFY_TOKEN
 *
 * Usage:
 *   /prod-logs
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { BorderedLoader, DynamicBorder } from "@mariozechner/pi-coding-agent";
import {
  truncateTail,
  formatSize,
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
} from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";
import {
  matchesKey,
  Key,
  truncateToWidth,
} from "@mariozechner/pi-tui";

// ── Types ───────────────────────────────────────────────────────────────────

interface CoolifyLogsResponse {
  logs?: string | string[];
}

/** Minimal theme interface for color application in the LogViewer. */
interface Theme {
  fg(color: string, text: string): string;
}

// ── Log Viewer Component ────────────────────────────────────────────────────

class LogViewer {
  lines: string[];

  /** Absolute index into `this.lines` of the highlighted cursor line.
   *  `-1` when there are no lines. */
  public cursorIndex: number = 0;

  /** Whether visual (range-selection) mode is active. */
  public visualMode: boolean = false;

  /** The line index where visual mode was entered (anchor of the selection
   *  range). Only meaningful when `visualMode` is true. */
  public visualAnchor: number = 0;

  /** Callback invoked when the user copies text (Enter in normal mode, y in
   *  visual mode). The resolved promise value from `ctx.ui.custom` determines
   *  whether the editor text is set. */
  public onCopy?: (text: string) => void;

  private scrollOffset: number = 0;
  private cachedWidth?: number;
  private cachedLines?: string[];
  private visibleHeight: number;

  public onClose?: () => void;
  public onRefresh?: () => void;

  constructor(lines: string[], visibleHeight: number) {
    this.lines = lines;
    this.visibleHeight = Math.max(1, visibleHeight);
    this.clampCursor();
  }

  /** Replace lines and reset all navigation state. */
  updateLines(lines: string[], chromeHeight: number): void {
    this.lines = lines;
    this.cursorIndex = 0;
    this.visualMode = false;
    this.visualAnchor = 0;
    this.scrollOffset = 0;
    this.visibleHeight = Math.min(lines.length, Math.max(10, process.stdout.rows - chromeHeight));
    this.clampCursor();
    this.clampViewport();
    this.invalidate();
  }

  get offset(): number {
    return this.scrollOffset;
  }

  get total(): number {
    return this.lines.length;
  }

  // ── Cursor / viewport helpers ──────────────────────────────────────────

  /** Clamp cursorIndex to a valid range.  Sets to -1 when there are no lines. */
  private clampCursor(): void {
    if (this.lines.length === 0) {
      this.cursorIndex = -1;
    } else {
      this.cursorIndex = Math.max(0, Math.min(this.cursorIndex, this.lines.length - 1));
    }
  }

  /** Adjust scrollOffset so cursorIndex stays within the visible viewport. */
  private clampViewport(): void {
    if (this.lines.length === 0) return;
    if (this.cursorIndex < this.scrollOffset) {
      this.scrollOffset = this.cursorIndex;
    } else if (this.cursorIndex >= this.scrollOffset + this.visibleHeight) {
      this.scrollOffset = this.cursorIndex - this.visibleHeight + 1;
    }
  }

  // ── Input handling ─────────────────────────────────────────────────────

  handleInput(data: string): void {
    // ── Mode-specific top-level keys ──────────────────────────────────

    // Escape in visual mode exits visual mode (clears selection)
    if (this.visualMode && matchesKey(data, Key.escape)) {
      this.visualMode = false;
      this.visualAnchor = 0;
      this.invalidate();
      return;
    }

    // Escape or q in normal mode closes the viewer
    if (!this.visualMode && (matchesKey(data, Key.escape) || matchesKey(data, "q"))) {
      this.onClose?.();
      return;
    }

    // Refresh works in both modes
    if (matchesKey(data, "r")) {
      this.onRefresh?.();
      return;
    }

    // ── Copy operations ───────────────────────────────────────────────

    // Enter in either mode copies the cursor line
    if (matchesKey(data, Key.enter)) {
      if (this.lines.length > 0 && this.cursorIndex >= 0) {
        this.onCopy?.(this.lines[this.cursorIndex]);
      }
      return;
    }

    // y in visual mode copies the selected range (oldest-first order)
    if (this.visualMode && matchesKey(data, "y")) {
      if (this.lines.length > 0) {
        const start = Math.min(this.visualAnchor, this.cursorIndex);
        const end = Math.max(this.visualAnchor, this.cursorIndex);
        // this.lines[0] = newest, so reverse the slice for oldest-first
        const text = this.lines.slice(start, end + 1).reverse().join("\n");
        this.onCopy?.(text);
      }
      return;
    }

    // ── Enter visual mode ─────────────────────────────────────────────

    if (!this.visualMode && matchesKey(data, "v") && this.cursorIndex >= 0) {
      this.visualMode = true;
      this.visualAnchor = this.cursorIndex;
      this.invalidate();
      return;
    }

    // ── Movement (cursorIndex moves; viewport auto-clamps) ────────────

    let moved = false;

    if (matchesKey(data, Key.up) || matchesKey(data, "k")) {
      this.cursorIndex--;
      moved = true;
    } else if (matchesKey(data, Key.down) || matchesKey(data, "j")) {
      this.cursorIndex++;
      moved = true;
    } else if (matchesKey(data, Key.pageUp)) {
      this.cursorIndex -= this.visibleHeight;
      moved = true;
    } else if (matchesKey(data, Key.pageDown) || matchesKey(data, Key.ctrl("f"))) {
      this.cursorIndex += this.visibleHeight;
      moved = true;
    } else if (matchesKey(data, Key.ctrl("b"))) {
      this.cursorIndex -= this.visibleHeight;
      moved = true;
    } else if (matchesKey(data, Key.home) || matchesKey(data, "g")) {
      // "g" once jumps to top (in vim, "gg" or a single "g" both work)
      this.cursorIndex = 0;
      moved = true;
    } else if (matchesKey(data, Key.end) || matchesKey(data, "G")) {
      this.cursorIndex = this.lines.length - 1;
      moved = true;
    }

    if (moved) {
      this.clampCursor();
      this.clampViewport();
      this.invalidate();
    }
  }

  // ── Rendering ─────────────────────────────────────────────────────────

  render(width: number, theme: Theme): string[] {
    if (this.cachedLines && this.cachedWidth === width) {
      return this.cachedLines;
    }

    const padLen = String(this.lines.length).length;
    const visibleLines = this.lines.slice(
      this.scrollOffset,
      this.scrollOffset + this.visibleHeight,
    );

    // Compute selection range (only when visual mode is active)
    const selStart = this.visualMode
      ? Math.min(this.visualAnchor, this.cursorIndex)
      : -1;
    const selEnd = this.visualMode
      ? Math.max(this.visualAnchor, this.cursorIndex)
      : -1;

    const result: string[] = [];
    for (let i = 0; i < visibleLines.length; i++) {
      const absIdx = this.scrollOffset + i;
      const lineNum = absIdx + 1;
      const numStr = String(lineNum).padStart(padLen, " ");

      // Base prefix widened by 2 chars to accommodate cursor/selection markers
      const basePrefix = `  ${numStr} │ `;

      const isCursor = absIdx === this.cursorIndex;
      const isSelected = this.visualMode
        && absIdx >= selStart
        && absIdx <= selEnd;

      if (isCursor) {
        // Cursor takes priority over selection highlight
        const line = `${basePrefix}> ${visibleLines[i]}`;
        const truncated = truncateToWidth(line, width, "");
        result.push(theme.fg("accent", truncated));
      } else if (isSelected) {
        const line = `${basePrefix}● ${visibleLines[i]}`;
        const truncated = truncateToWidth(line, width, "");
        result.push(theme.fg("success", truncated));
      } else {
        const line = `${basePrefix}  ${visibleLines[i]}`;
        result.push(truncateToWidth(line, width, ""));
      }
    }

    // Pad to visibleHeight if fewer lines
    while (result.length < this.visibleHeight) {
      result.push("~");
    }

    this.cachedWidth = width;
    this.cachedLines = result;
    return result;
  }

  invalidate(): void {
    this.cachedWidth = undefined;
    this.cachedLines = undefined;
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function resolveVar(name: string): string | undefined {
  return process.env[`PI_${name.toUpperCase()}`];
}

async function fetchLogs(
  host: string,
  appUuid: string,
  token: string,
  signal?: AbortSignal,
): Promise<string[]> {
  const url = `${host}/api/v1/applications/${appUuid}/logs`;
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
    signal,
  });

  if (!response.ok) {
    throw new Error(
      `Coolify API returned ${response.status} ${response.statusText}`,
    );
  }

  const data: CoolifyLogsResponse = await response.json();

  if (data.logs === undefined || data.logs === null) {
    return ["(no logs returned)"];
  }

  if (Array.isArray(data.logs)) {
    return data.logs;
  }

  if (typeof data.logs === "string") {
    return data.logs.split("\n");
  }

  return ["(unexpected log format)"];
}

// ── Extension ───────────────────────────────────────────────────────────────

export default function prodLogsExtension(pi: ExtensionAPI) {
  // ── fetch_production_logs tool ─────────────────────────────────────────

  pi.registerTool({
    name: "fetch_production_logs",
    label: "Fetch Production Logs",
    description:
      "Fetch recent production logs from the deployed application via the Coolify API. " +
      "Use this tool when investigating production errors, checking server behavior, " +
      "debugging deployed issues, or when the user asks about production status, " +
      "logs, errors, or application behavior in the deployed environment. " +
      "Output is truncated at 50KB / 2000 lines — use a smaller 'tail' value or " +
      "a narrower 'grep' pattern to reduce output if truncation occurs.",
    promptSnippet:
      "Fetch recent production logs from deployed app (param: tail, grep)",
    promptGuidelines: [
      "Use fetch_production_logs when investigating production errors, checking deployed application behavior, or when the user asks about production status or recent activity.",
      "Use the 'grep' parameter to filter logs by a case-insensitive substring (e.g., grep: 'error', grep: 'timeout'). This reduces output size and helps find relevant entries.",
      "Start with a small 'tail' value (e.g., tail: 50) and increase only if needed. Large tail values may hit the 50KB/2000-line truncation limit.",
    ],
    parameters: Type.Object({
      tail: Type.Optional(
        Type.Number({
          description:
            "Number of most recent log lines to return. Default: 200. Use a smaller value to reduce output size.",
        }),
      ),
      grep: Type.Optional(
        Type.String({
          description:
            "Case-insensitive substring filter for log lines. Only lines containing this string are returned. Use to narrow results to relevant entries.",
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
      const host = resolveVar("coolify_host");
      const appUuid = resolveVar("coolify_app_uuid");
      const token = resolveVar("coolify_token");

      const missing: string[] = [];
      if (!host) missing.push("PI_COOLIFY_HOST");
      if (!appUuid) missing.push("PI_COOLIFY_APP_UUID");
      if (!token) missing.push("PI_COOLIFY_TOKEN");

      if (missing.length > 0) {
        return {
          content: [
            {
              type: "text",
              text:
                `Cannot fetch production logs: the following environment variables are not set:\n` +
                missing.map((v) => `  - ${v}`).join("\n") +
                `\n\nEnsure these are configured in your pi environment.`,
            },
          ],
          isError: true,
        };
      }

      // Fetch logs
      let lines: string[];
      try {
        lines = await fetchLogs(host!, appUuid!, token!, signal);
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        return {
          content: [
            {
              type: "text",
              text: `Failed to fetch production logs: ${message}`,
            },
          ],
          isError: true,
        };
      }

      // Handle empty logs
      if (lines.length === 0) {
        return {
          content: [{ type: "text", text: "No log entries found." }],
        };
      }

      // Recent entries first (consistent with the /prod-logs viewer)
      lines.reverse();

      // Apply grep filter if provided
      if (params.grep) {
        const pattern = params.grep.toLowerCase();
        lines = lines.filter((line) => line.toLowerCase().includes(pattern));
      }

      // Record pre-tail line count for details
      const lineCount = lines.length;

      // Apply tail limit
      const tail = params.tail ?? 200;
      lines = lines.slice(0, tail);

      // Join into a single string
      let output = lines.join("\n");

      // Apply output truncation
      const truncation = truncateTail(output, {
        maxLines: DEFAULT_MAX_LINES,
        maxBytes: DEFAULT_MAX_BYTES,
      });

      if (truncation.truncated) {
        output =
          truncation.content +
          `\n\n[Output truncated: ${truncation.outputLines} of ${truncation.totalLines} lines (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)}). ` +
          `Use a smaller 'tail' value or narrower 'grep' pattern to reduce output.]`;
      } else {
        output = truncation.content;
      }

      return {
        content: [{ type: "text", text: output }],
        details: { lineCount },
      };
    },
  });

  // ── /prod-logs interactive command ─────────────────────────────────────

  pi.registerCommand("prod-logs", {
    description: "View production application logs via Coolify API",
    handler: async (_args, ctx) => {
      // ── Validate credentials ──────────────────────────────────────────

      const host = resolveVar("coolify_host");
      const appUuid = resolveVar("coolify_app_uuid");
      const token = resolveVar("coolify_token");

      const missing: string[] = [];
      if (!host) missing.push("PI_COOLIFY_HOST");
      if (!appUuid) missing.push("PI_COOLIFY_APP_UUID");
      if (!token) missing.push("PI_COOLIFY_TOKEN");

      if (missing.length > 0) {
        ctx.ui.notify(
          `Missing environment variables: ${missing.join(", ")}`,
          "error",
        );
        return;
      }

      // ── Fetch logs with loader UI ─────────────────────────────────────

      const logLines = await ctx.ui.custom<string[] | null>(
        (tui, theme, _kb, done) => {
          const loader = new BorderedLoader(
            tui,
            theme,
            "Fetching production logs...",
          );
          loader.onAbort = () => done(null);

          fetchLogs(host!, appUuid!, token!, loader.signal)
            .then(done)
            .catch((err) => {
              console.error("[prod-logs] Fetch failed:", err);
              done(null);
            });

          return loader;
        },
      );

      if (logLines === null) {
        ctx.ui.notify("Cancelled or fetch failed — check logs for details", "info");
        return;
      }

      if (logLines.length === 0) {
        ctx.ui.notify("No log entries found", "info");
        return;
      }

      // Recent entries first
      logLines.reverse();

      // ── Display logs in scrollable viewer ─────────────────────────────

      // Reserve lines for borders, header, footer, scroll info
      const chromeHeight = 10;

      let logLinesMut = logLines;
      let loading = false;

      const visibleLogLines = () =>
        Math.min(logLinesMut.length, Math.max(10, process.stdout.rows - chromeHeight));

      const viewer = new LogViewer(logLinesMut, visibleLogLines());

      const doRefresh = (tui: { requestRender: () => void }) => {
        if (loading) return;
        loading = true;
        tui.requestRender();

        fetchLogs(host!, appUuid!, token!)
          .then((lines) => {
            lines.reverse();
            logLinesMut = lines;
            viewer.updateLines(lines, chromeHeight);
            loading = false;
            tui.requestRender();
          })
          .catch((err) => {
            console.error("[prod-logs] Refresh failed:", err);
            loading = false;
            tui.requestRender();
          });
      };

      // ── Interactive log browser (returns copied text or null) ─────────

      const copiedText = await ctx.ui.custom<string | null>(
        (tui, theme, _kb, done) => {
          viewer.onClose = () => done(null);
          viewer.onRefresh = () => doRefresh(tui);
          viewer.onCopy = (text: string) => done(text);

          return {
            render(width: number) {
              const pct = viewer.total > 0
                ? Math.round((viewer.offset / viewer.total) * 100)
                : 0;
              const from = viewer.offset + 1;
              const to = Math.min(
                viewer.offset + visibleLogLines(),
                viewer.total,
              );

              const result: string[] = [];
              const border = theme.fg("accent", "─".repeat(width));
              result.push(border);
              result.push(truncateToWidth(
                theme.fg("accent", theme.bold(" Production Logs")),
                width,
                "",
              ));

              const countText = loading
                ? " Refreshing..."
                : ` ${logLinesMut.length} lines`;
              result.push(truncateToWidth(theme.fg("muted", countText), width, ""));
              result.push(truncateToWidth(theme.fg("dim", "─".repeat(40)), width, ""));

              const infoText = ` Lines ${from}-${to} of ${logLinesMut.length} (${pct}%)`;
              result.push(truncateToWidth(theme.fg("dim", infoText), width, ""));

              // Log lines
              const logRendered = viewer.render(width, theme);
              result.push(...logRendered);

              // Mode-aware help text
              const helpLine = loading
                ? " Refreshing..."
                : viewer.visualMode
                  ? " VISUAL: j/k extend  ·  y copy  ·  Esc cancel  ·  Enter copy line"
                  : " ↑↓/jk scroll  ·  PgUp/PgDn page  ·  Home/End jump  ·  v visual  ·  Enter copy line  ·  r refresh  ·  Esc close";
              result.push(truncateToWidth(
                theme.fg("dim", helpLine),
                width,
                "",
              ));
              result.push(border);

              return result;
            },

            invalidate() {
              viewer.invalidate();
            },

            handleInput(data: string) {
              viewer.handleInput(data);
              tui.requestRender();
            },
          };
        },
      );

      // ── Place copied text in editor ────────────────────────────────────

      if (copiedText !== null) {
        ctx.ui.setEditorText(copiedText);
      }

      ctx.ui.notify("Log viewer closed", "info");
    },
  });
}
