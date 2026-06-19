/**
 * Production Metrics Tools & Browser
 *
 * Fetches and displays production telemetry metrics from /api/v1/metrics/overview.
 *
 * Credentials are read from environment variables:
 *   PI_API_TOKEN         — Bearer token for API auth
 *   PI_SERVICE_FQDN_WEB  — Production domain (e.g., https://musiclibrary.example.com)
 *
 * Tools:
 *   fetch_production_metrics_overview  — Fetch metrics summary for triage
 *
 * Commands:
 *   /prod-metrics  — Interactive TUI for browsing production metrics
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import {
  truncateTail,
  formatSize,
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
} from "@mariozechner/pi-coding-agent";
import { matchesKey, Key, truncateToWidth } from "@mariozechner/pi-tui";
import { Type } from "typebox";

import {
  fetchOverview,
  buildUrl,
  resolveVar,
  formatCompactForLLM,
  formatOverview,
  type OverviewResponse,
  type MetricsGroup,
} from "./src/client.ts";

// ── Helpers ───────────────────────────────────────────────────────────────

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
      `Use narrower filters (categories, since) to reduce output.]`
    );
  }

  return truncation.content;
}

// ── Extension ─────────────────────────────────────────────────────────────

export default function prodMetricsExtension(pi: ExtensionAPI) {
  // ── fetch_production_metrics_overview tool ─────────────────────────────

  pi.registerTool({
    name: "fetch_production_metrics_overview",
    label: "Fetch Production Metrics Overview",
    description:
      "Fetch production telemetry metrics overview from /api/v1/metrics/overview. " +
      "Returns bounded category summaries for HTTP, Oban, Repo, external API, VM, " +
      "and ErrorTracker telemetry where data is present. Use for operational triage: " +
      "identify slow routes, backlogged queues, high API latencies, and error counters.",
    promptSnippet:
      "Fetch production metrics overview data using PI_API_TOKEN and PI_SERVICE_FQDN_WEB",
    promptGuidelines: [
      "Use fetch_production_metrics_overview to inspect application health, latency, and error rates in production.",
      "The overview returns bounded summaries (not raw datapoints) with configurable since window and optional category filters.",
      "For timing metrics, p95 is the best indicator of tail latency. For counters, look at event counts in the since window.",
      "Data may be stale by up to 5 seconds (storage flush interval).",
    ],
    parameters: Type.Object({
      since: Type.Optional(
        Type.String({
          description:
            "Duration window: '15m', '1h', or '24h'. Default: '1h'. Values above '24h' are clamped.",
        }),
      ),
      categories: Type.Optional(
        Type.String({
          description:
            "Comma-separated category ids, e.g. 'http,oban'. Omit for all categories.",
        }),
      ),
      top: Type.Optional(
        Type.Number({
          description: "Top-N label limit per metric. Default: 10, max: 50.",
        }),
      ),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, _ctx) {
      if (signal?.aborted) {
        return { content: [{ type: "text", text: "Cancelled" }] };
      }

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
                `Cannot fetch production metrics: the following environment variables are not set:\n` +
                missing.map((v) => `  - ${v}`).join("\n") +
                `\n\nEnsure these are configured in your pi environment.`,
            },
          ],
          isError: true,
        };
      }

      // Build query params
      const queryParams: Record<string, string> = {};
      if (params.since !== undefined && params.since !== null) {
        queryParams.since = params.since;
      }
      if (params.categories !== undefined && params.categories !== null) {
        queryParams.categories = params.categories;
      }
      if (params.top !== undefined && params.top !== null) {
        queryParams.top = String(params.top);
      }

      const url = buildUrl(fqdn!, "/api/v1/metrics/overview", queryParams);

      // Fetch
      let data: OverviewResponse;
      try {
        data = await fetchOverview(url, token!, signal);
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        return {
          content: [
            {
              type: "text",
              text: `Failed to fetch production metrics overview: ${message}`,
            },
          ],
          isError: true,
        };
      }

      // Check for completely empty results
      const hasData = data.categories.some((c) =>
        c.metrics.some((m) => m.total_count > 0),
      );
      if (!hasData) {
        return {
          content: [
            {
              type: "text",
              text: `No telemetry data found in the ${data.effective_since} window.`,
            },
          ],
          details: {
            since: data.effective_since,
            generated_at: data.generated_at,
            categories_with_data: 0,
          },
        };
      }

      // Format for LLM triage
      const compact = formatCompactForLLM(data);
      const output = applyOutputTruncation(compact);

      const categoriesWithData = data.categories.filter((c) =>
        c.metrics.some((m) => m.total_count > 0),
      ).length;

      return {
        content: [{ type: "text", text: output }],
        details: {
          since: data.effective_since,
          generated_at: data.generated_at,
          top: data.top,
          top_clamped: data.top_clamped,
          categories_total: data.categories.length,
          categories_with_data: categoriesWithData,
        },
      };
    },
  });

  // ── /prod-metrics TUI ─────────────────────────────────────────────────

  type TuiRow =
    | { type: "category"; name: string; id: string }
    | {
        type: "metric";
        name: string;
        kind: "summary" | "counter";
        unit: string | null;
        totalCount: number;
      }
    | {
        type: "group";
        label: string;
        group: MetricsGroup;
        kind: "summary" | "counter";
        unit: string | null;
      };

  interface Theme {
    fg(color: string, text: string): string;
    bold(text: string): string;
  }

  const SINCE_OPTIONS = ["15m", "1h", "24h"] as const;

  class MetricsBrowser {
    private mode: "list" | "loading" = "loading";
    private data: OverviewResponse | null = null;
    private since: string = "1h";
    private cursorIndex: number = 0;
    private scrollOffset: number = 0;
    private rows: TuiRow[] = [];

    onClose?: () => void;
    onCopy?: (text: string) => void;

    private cachedWidth?: number;
    private cachedLines?: string[];

    private currentAbortController?: AbortController;
    private readonly baseUrl: string;
    private readonly token: string;
    private readonly requestRender: () => void;
    private readonly notify: (
      msg: string,
      level: "error" | "info" | "warning",
    ) => void;

    constructor(
      baseUrl: string,
      token: string,
      requestRender: () => void,
      notify: (msg: string, level: "error" | "info" | "warning") => void,
    ) {
      this.baseUrl = baseUrl;
      this.token = token;
      this.requestRender = requestRender;
      this.notify = notify;
    }

    initialLoad(): void {
      this.loadData();
    }

    close(): void {
      this.abortInFlight();
    }

    private get visibleHeight(): number {
      return Math.max(10, process.stdout.rows - 4);
    }

    private clampCursor(): void {
      if (this.rows.length === 0) {
        this.cursorIndex = -1;
      } else {
        this.cursorIndex = Math.max(
          0,
          Math.min(this.cursorIndex, this.rows.length - 1),
        );
      }
    }

    private clampViewport(): void {
      if (this.rows.length === 0) return;
      if (this.cursorIndex < this.scrollOffset) {
        this.scrollOffset = this.cursorIndex;
      } else if (this.cursorIndex >= this.scrollOffset + this.visibleHeight) {
        this.scrollOffset = this.cursorIndex - this.visibleHeight + 1;
      }
      this.scrollOffset = Math.max(
        0,
        Math.min(this.scrollOffset, this.rows.length - 1),
      );
    }

    private buildRows(): TuiRow[] {
      const rows: TuiRow[] = [];
      if (!this.data) return rows;
      for (const cat of this.data.categories) {
        rows.push({ type: "category", name: cat.name, id: cat.id });
        for (const m of cat.metrics) {
          rows.push({
            type: "metric",
            name: m.name,
            kind: m.kind,
            unit: m.unit,
            totalCount: m.total_count,
          });
          for (const g of m.groups) {
            rows.push({
              type: "group",
              label: g.label ?? "(all)",
              group: g,
              kind: m.kind,
              unit: m.unit,
            });
          }
        }
      }
      return rows;
    }

    private abortInFlight(): void {
      if (this.currentAbortController) {
        this.currentAbortController.abort();
        this.currentAbortController = undefined;
      }
    }

    private loadData(): void {
      this.abortInFlight();
      this.mode = "loading";
      this.invalidate();
      this.requestRender();

      const url = buildUrl(this.baseUrl, "/api/v1/metrics/overview", {
        since: this.since,
      });
      const controller = new AbortController();
      this.currentAbortController = controller;

      fetchOverview(url, this.token, controller.signal)
        .then((data) => {
          this.data = data;
          this.rows = this.buildRows();
          this.cursorIndex = this.rows.length > 0 ? 0 : -1;
          this.scrollOffset = 0;
          this.clampViewport();
          this.mode = "list";
          this.invalidate();
          this.requestRender();
        })
        .catch((err) => {
          if (err instanceof Error && err.name === "AbortError") return;
          this.mode = "list";
          const msg = err instanceof Error ? err.message : String(err);
          this.notify(`Failed to load metrics: ${msg}`, "error");
          this.invalidate();
          this.requestRender();
        });
    }

    private switchWindow(since: string): void {
      if (this.mode === "loading") return;
      this.since = since;
      this.loadData();
    }

    handleInput(data: string): void {
      if (matchesKey(data, Key.escape) || matchesKey(data, "q")) {
        this.onClose?.();
        return;
      }

      if (matchesKey(data, "r")) {
        if (this.mode !== "loading") this.loadData();
        return;
      }

      if (matchesKey(data, "1")) {
        this.switchWindow("15m");
        return;
      }
      if (matchesKey(data, "2")) {
        this.switchWindow("1h");
        return;
      }
      if (matchesKey(data, "3")) {
        this.switchWindow("24h");
        return;
      }

      if (this.mode !== "list") return;

      if (matchesKey(data, "c")) {
        const row = this.rows[this.cursorIndex];
        if (row) {
          const text = this.rowToCopyText(row);
          if (text) this.onCopy?.(text);
        }
        return;
      }

      let moved = false;
      if (matchesKey(data, Key.up) || matchesKey(data, "k")) {
        this.cursorIndex--;
        moved = true;
      } else if (matchesKey(data, Key.down) || matchesKey(data, "j")) {
        this.cursorIndex++;
        moved = true;
      } else if (matchesKey(data, Key.pageDown)) {
        this.cursorIndex += this.visibleHeight;
        moved = true;
      } else if (matchesKey(data, Key.pageUp)) {
        this.cursorIndex -= this.visibleHeight;
        moved = true;
      } else if (matchesKey(data, Key.home) || matchesKey(data, "g")) {
        this.cursorIndex = 0;
        moved = true;
      } else if (
        matchesKey(data, Key.end) ||
        matchesKey(data, Key.shift("g"))
      ) {
        this.cursorIndex = this.rows.length - 1;
        moved = true;
      }

      if (moved) {
        this.clampCursor();
        this.clampViewport();
        this.invalidate();
      }
    }

    private rowToCopyText(row: TuiRow): string {
      switch (row.type) {
        case "category":
          return `Category: ${row.name}`;
        case "metric":
          return `Metric: ${row.name} (${row.kind}, ${row.totalCount} datapoints)`;
        case "group": {
          const parts = [`${row.label}: n=${row.group.count}`];
          if (row.group.avg !== null) parts.push(`avg=${row.group.avg}`);
          if (row.group.p95 !== null) parts.push(`p95=${row.group.p95}`);
          if (row.group.max !== null) parts.push(`max=${row.group.max}`);
          return parts.join(", ");
        }
      }
    }

    render(width: number, theme: Theme): string[] {
      if (this.cachedLines && this.cachedWidth === width)
        return this.cachedLines;
      const result =
        this.mode === "loading"
          ? this.renderLoading(width, theme)
          : this.renderList(width, theme);
      this.cachedWidth = width;
      this.cachedLines = result;
      return result;
    }

    private renderLoading(width: number, theme: Theme): string[] {
      const border = theme.fg("accent", "─".repeat(width));
      const result: string[] = [border];
      const viewportRows = this.visibleHeight + 2;
      const mid = Math.floor(viewportRows / 2);
      for (let i = 1; i < viewportRows - 1; i++) {
        result.push(
          i === mid
            ? truncateToWidth(
                theme.fg("muted", "  Loading metrics…"),
                width,
                "",
              )
            : "",
        );
      }
      result.push(border);
      return result;
    }

    private renderList(width: number, theme: Theme): string[] {
      const border = theme.fg("accent", "─".repeat(width));
      const result: string[] = [];

      result.push(border);
      const headerText = ` Production Metrics — ${this.since} window`;
      result.push(
        truncateToWidth(theme.fg("accent", theme.bold(headerText)), width, ""),
      );
      result.push(
        truncateToWidth(theme.fg("dim", "─".repeat(width)), width, ""),
      );

      if (this.rows.length === 0) {
        const msg = this.data
          ? "No data in the current window"
          : "No data loaded";
        result.push(truncateToWidth(theme.fg("muted", `  ${msg}`), width, ""));
        const chromeLines = 3;
        while (result.length < this.visibleHeight + chromeLines)
          result.push("");
      } else {
        const endIdx = Math.min(
          this.scrollOffset + this.visibleHeight,
          this.rows.length,
        );
        for (let i = this.scrollOffset; i < endIdx; i++) {
          const row = this.rows[i];
          if (!row) continue;
          const isCursor = i === this.cursorIndex;
          const cursor = isCursor ? "▶" : " ";
          const line = this.formatRow(row, theme);
          const fullLine = `${cursor} ${line}`;
          result.push(
            truncateToWidth(
              isCursor ? theme.fg("accent", fullLine) : fullLine,
              width,
              "",
            ),
          );
        }
        const targetLines = 3 + this.visibleHeight;
        while (result.length < targetLines) result.push("");
      }

      const windowLabel = SINCE_OPTIONS.map((s, i) => `${i + 1}=${s}`).join(
        "  ",
      );
      result.push(
        truncateToWidth(
          theme.fg("dim", ` ${windowLabel}  r=refresh  j/k=navigate  c=copy`),
          width,
          "",
        ),
      );
      result.push(truncateToWidth(theme.fg("dim", ` q=quit`), width, ""));
      result.push(border);

      return result;
    }

    private formatRow(row: TuiRow, theme: Theme): string {
      switch (row.type) {
        case "category":
          return theme.bold(row.name) + ":";
        case "metric": {
          const unitSuffix = row.unit ? ` (${row.unit})` : "";
          return `  ${row.name}${unitSuffix}  (${row.totalCount} datapoints)`;
        }
        case "group": {
          const label = row.label;
          let line = `    ${label}  n=${row.group.count}`;
          if (row.kind === "counter") {
            line += `  events`;
          } else {
            if (row.group.avg !== null) line += `  avg=${row.group.avg}`;
            if (row.group.p95 !== null) line += `  p95=${row.group.p95}`;
            if (row.group.max !== null) line += `  max=${row.group.max}`;
            if (row.group.latest !== null)
              line += `  latest=${row.group.latest}`;
          }
          return line;
        }
      }
    }

    invalidate(): void {
      this.cachedWidth = undefined;
      this.cachedLines = undefined;
    }
  }

  pi.registerCommand("prod-metrics", {
    description:
      "Interactive TUI for browsing production telemetry metrics overview. " +
      "Switch between time windows (15m, 1h, 24h), navigate summaries, refresh data, and copy rows.",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify(
          "The /prod-metrics TUI is only available in interactive TUI mode. Use the fetch_production_metrics_overview LLM tool instead.",
          "warning",
        );
        return;
      }

      const token = resolveVar("api_token");
      const fqdn = resolveVar("service_fqdn_web");

      const missing: string[] = [];
      if (!token) missing.push("PI_API_TOKEN");
      if (!fqdn) missing.push("PI_SERVICE_FQDN_WEB");

      if (missing.length > 0) {
        ctx.ui.notify(
          `Cannot open metrics browser: missing ${missing.join(", ")}`,
          "error",
        );
        return;
      }

      let browser: MetricsBrowser | undefined;

      try {
        await ctx.ui.custom<null>((tui, theme, _kb, done) => {
          browser = new MetricsBrowser(
            fqdn!,
            token!,
            () => tui.requestRender(),
            (msg, level) => ctx.ui.notify(msg, level),
          );

          browser.onClose = () => {
            browser?.close();
            done(null);
          };
          browser.onCopy = (text: string) => {
            ctx.ui.setEditorText(text);
            ctx.ui.notify("Copied selected metrics row to editor", "info");
          };
          browser.initialLoad();

          return {
            render(width: number) {
              return browser!.render(width, theme);
            },
            invalidate() {
              browser!.invalidate();
            },
            handleInput(data: string) {
              browser!.handleInput(data);
              tui.requestRender();
            },
          };
        });
      } finally {
        browser?.close();
      }

      ctx.ui.notify("Metrics browser closed", "info");
    },
  });
}
