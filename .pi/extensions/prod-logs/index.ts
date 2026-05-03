/**
 * Production Log Viewer
 *
 * Fetches and displays application logs from the Coolify API.
 *
 * Credentials are read from environment variables following Hurl conventions:
 *   HURL_VARIABLE_coolify_host
 *   HURL_VARIABLE_coolify_app_uuid
 *   HURL_VARIABLE_coolify_token
 *
 * Usage:
 *   /prod-logs
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { BorderedLoader, DynamicBorder } from "@mariozechner/pi-coding-agent";
import {
  matchesKey,
  Key,
  truncateToWidth,
} from "@mariozechner/pi-tui";

// ── Types ───────────────────────────────────────────────────────────────────

interface CoolifyLogsResponse {
  logs?: string | string[];
}

// ── Log Viewer Component ────────────────────────────────────────────────────

class LogViewer {
  lines: string[];
  private scrollOffset: number = 0;
  private cachedWidth?: number;
  private cachedLines?: string[];
  private visibleHeight: number;

  public onClose?: () => void;
  public onRefresh?: () => void;

  constructor(lines: string[], visibleHeight: number) {
    this.lines = lines;
    this.visibleHeight = Math.max(1, visibleHeight);
  }

  /** Replace lines and reset scroll to top. */
  updateLines(lines: string[], chromeHeight: number): void {
    this.lines = lines;
    this.scrollOffset = 0;
    this.visibleHeight = Math.min(lines.length, Math.max(10, process.stdout.rows - chromeHeight));
    this.invalidate();
  }

  get offset(): number {
    return this.scrollOffset;
  }

  get total(): number {
    return this.lines.length;
  }

  handleInput(data: string): void {
    if (matchesKey(data, Key.escape) || matchesKey(data, "q")) {
      this.onClose?.();
      return;
    }

    if (matchesKey(data, "r")) {
      this.onRefresh?.();
      return;
    }

    if (matchesKey(data, Key.up) || matchesKey(data, "k")) {
      this.scrollOffset = Math.max(0, this.scrollOffset - 1);
      this.invalidate();
    } else if (matchesKey(data, Key.down) || matchesKey(data, "j")) {
      const maxOffset = Math.max(0, this.lines.length - this.visibleHeight);
      this.scrollOffset = Math.min(maxOffset, this.scrollOffset + 1);
      this.invalidate();
    } else if (matchesKey(data, Key.pageUp)) {
      this.scrollOffset = Math.max(0, this.scrollOffset - this.visibleHeight);
      this.invalidate();
    } else if (matchesKey(data, Key.pageDown) || matchesKey(data, Key.ctrl("f"))) {
      const maxOffset = Math.max(0, this.lines.length - this.visibleHeight);
      this.scrollOffset = Math.min(maxOffset, this.scrollOffset + this.visibleHeight);
      this.invalidate();
    } else if (matchesKey(data, Key.ctrl("b"))) {
      this.scrollOffset = Math.max(0, this.scrollOffset - this.visibleHeight);
      this.invalidate();
    } else if (matchesKey(data, Key.home) || matchesKey(data, "g")) {
      // "g" twice = go to top; single "g" handled as first press
      this.scrollOffset = 0;
      this.invalidate();
    } else if (matchesKey(data, Key.end) || matchesKey(data, "G")) {
      this.scrollOffset = Math.max(0, this.lines.length - this.visibleHeight);
      this.invalidate();
    }
  }

  render(width: number): string[] {
    if (this.cachedLines && this.cachedWidth === width) {
      return this.cachedLines;
    }

    const padLen = String(this.lines.length).length;
    const visibleLines = this.lines.slice(
      this.scrollOffset,
      this.scrollOffset + this.visibleHeight,
    );

    const result: string[] = [];
    for (let i = 0; i < visibleLines.length; i++) {
      const lineNum = this.scrollOffset + i + 1;
      const numStr = String(lineNum).padStart(padLen, " ");
      const prefix = ` ${numStr} │ `;
      const content = truncateToWidth(
        `${prefix}${visibleLines[i]}`,
        width,
        "",
      );
      result.push(content);
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
  return process.env[`HURL_VARIABLE_${name}`];
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
  pi.registerCommand("prod-logs", {
    description: "View production application logs via Coolify API",
    handler: async (_args, ctx) => {
      // ── Validate credentials ──────────────────────────────────────────

      const host = resolveVar("coolify_host");
      const appUuid = resolveVar("coolify_app_uuid");
      const token = resolveVar("coolify_token");

      const missing: string[] = [];
      if (!host) missing.push("HURL_VARIABLE_coolify_host");
      if (!appUuid) missing.push("HURL_VARIABLE_coolify_app_uuid");
      if (!token) missing.push("HURL_VARIABLE_coolify_token");

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

      await ctx.ui.custom<void>((tui, theme, _kb, done) => {
        viewer.onClose = () => done();
        viewer.onRefresh = () => doRefresh(tui);

        return {
          render(width: number) {
            // Update scroll info
            const pct = viewer.total > 0
              ? Math.round((viewer.offset / viewer.total) * 100)
              : 0;
            const from = viewer.offset + 1;
            const to = Math.min(
              viewer.offset + visibleLogLines(),
              viewer.total,
            );
            // Build result manually
            const result: string[] = [];
            const border = theme.fg("accent", "─".repeat(width));
            result.push(border);
            result.push(truncateToWidth(theme.fg("accent", theme.bold(" Production Logs")), width, ""));

            const countText = loading
              ? " Refreshing..."
              : ` ${logLinesMut.length} lines`;
            result.push(truncateToWidth(theme.fg("muted", countText), width, ""));
            result.push(truncateToWidth(theme.fg("dim", "─".repeat(40)), width, ""));

            const infoText = ` Lines ${from}-${to} of ${logLinesMut.length} (${pct}%)`;
            result.push(truncateToWidth(theme.fg("dim", infoText), width, ""));

            // Log lines
            const logRendered = viewer.render(width);
            result.push(...logRendered);

            const helpLine = loading
              ? " Refreshing..."
              : " ↑↓/jk scroll  ·  PgUp/PgDn page  ·  Home/End jump  ·  r refresh  ·  Esc close";
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
      });

      ctx.ui.notify("Log viewer closed", "info");
    },
  });
}
