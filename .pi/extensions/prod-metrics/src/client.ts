/**
 * Production Metrics API client and formatting utilities.
 *
 * Fetches telemetry overview data from the /api/v1/metrics/overview endpoint
 * and formats it for LLM consumption and TUI display.
 */

// ── Types ─────────────────────────────────────────────────────────────────

export interface MetricsGroup {
  label: string | null;
  count: number;
  latest: number | null;
  latest_at: string | null;
  avg: number | null;
  max: number | null;
  p50: number | null;
  p95: number | null;
  p99: number | null;
}

export interface MetricSummary {
  key: string;
  name: string;
  kind: "summary" | "counter";
  unit: string | null;
  tags: string[];
  total_count: number;
  groups: MetricsGroup[];
}

export interface CategoryOverview {
  id: string;
  name: string;
  metrics: MetricSummary[];
}

export interface OverviewResponse {
  generated_at: string;
  requested_since: string;
  effective_since: string;
  since_time: number;
  top: number;
  top_clamped: boolean;
  categories: CategoryOverview[];
}

// ── URL construction ──────────────────────────────────────────────────────

export function resolveVar(name: string): string | undefined {
  return process.env[`PI_${name.toUpperCase()}`];
}

export function buildUrl(
  base: string,
  path: string,
  params?: Record<string, string>,
): string {
  let url = base.replace(/\/+$/, "");
  if (!/^https?:\/\//i.test(url)) {
    const isLocal =
      url.startsWith("localhost") ||
      url.startsWith("127.") ||
      url.startsWith("0.0.0.0") ||
      url.startsWith("[::1]");
    url = `${isLocal ? "http" : "https"}://${url}`;
  }
  url = `${url}${path}`;

  if (params) {
    const searchParams = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== null && value !== "") {
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

// ── HTTP ──────────────────────────────────────────────────────────────────

export async function fetchOverview(
  url: string,
  token: string,
  signal?: AbortSignal,
): Promise<OverviewResponse> {
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

  return validateOverview(data);
}

function validateOverview(data: unknown): OverviewResponse {
  const obj = data as Record<string, unknown>;
  if (!obj.categories || !Array.isArray(obj.categories)) {
    throw new Error(
      `Unexpected API response: 'categories' field is missing or not an array. Got: ${
        obj.categories === null ? "null" : typeof obj.categories
      }.`,
    );
  }
  return data as OverviewResponse;
}

// ── Formatting ────────────────────────────────────────────────────────────

function formatDuration(ms: number): string {
  if (ms < 1) return `${(ms * 1000).toFixed(1)}μs`;
  if (ms < 1000) return `${ms.toFixed(1)}ms`;
  return `${(ms / 1000).toFixed(2)}s`;
}

function formatValue(value: number | null, unit: string | null): string {
  if (value === null || value === undefined) return "—";

  if (unit === "millisecond") return formatDuration(value);
  if (unit === "megabyte") return `${value.toFixed(1)} MB`;
  if (unit === "kilobyte") return `${value.toFixed(1)} KB`;

  return typeof value === "number" ? value.toFixed(2) : String(value);
}

function formatGroup(
  g: MetricsGroup,
  kind: "summary" | "counter",
  unit: string | null,
): string {
  const label = g.label ?? "(all)";

  if (kind === "counter") {
    return `  ${label}: ${g.count} events`;
  }

  const parts: string[] = [label];
  parts.push(`n=${g.count}`);

  if (g.latest !== null) parts.push(`latest=${formatValue(g.latest, unit)}`);
  if (g.avg !== null) parts.push(`avg=${formatValue(g.avg, unit)}`);
  if (g.max !== null) parts.push(`max=${formatValue(g.max, unit)}`);
  if (g.p95 !== null) parts.push(`p95=${formatValue(g.p95, unit)}`);
  if (g.p50 !== null) parts.push(`p50=${formatValue(g.p50, unit)}`);

  return `  ${parts.join("  ")}`;
}

function formatMetric(m: MetricSummary): string[] {
  const lines: string[] = [];
  const unitSuffix = m.unit ? ` (${m.unit})` : "";

  if (m.groups.length === 0) {
    lines.push(`${m.name}${unitSuffix} — no data in window`);
    return lines;
  }

  lines.push(
    `${m.name}${unitSuffix} (${m.total_count} datapoints, ${m.groups.length} groups):`,
  );

  for (const g of m.groups) {
    lines.push(formatGroup(g, m.kind, m.unit));
  }

  return lines;
}

function formatCategory(c: CategoryOverview): string[] {
  const lines: string[] = [];

  if (c.metrics.length === 0) {
    lines.push(`${c.name}: no matching metrics`);
    return lines;
  }

  lines.push(`${c.name}:`);

  for (const m of c.metrics) {
    lines.push(...formatMetric(m));
    lines.push("");
  }

  return lines;
}

export function formatOverview(data: OverviewResponse): string {
  const lines: string[] = [];

  // Header
  const clampedNote = data.top_clamped ? " (clamped)" : "";
  lines.push(
    `Production Metrics Overview — ${data.effective_since} window, top ${data.top}${clampedNote}`,
  );
  lines.push(`Generated at ${data.generated_at}`);
  lines.push("");

  // Per category
  for (const c of data.categories) {
    lines.push(...formatCategory(c));
  }

  // Footer with note about staleness
  lines.push("Data may be stale by up to 5 seconds (storage flush interval).");

  return lines.join("\n");
}

/**
 * Formats a compact summary suitable for LLM triage.
 * Prioritizes indicators of operational health: slowest routes, errored statuses,
 * backlogged queues, highest API latencies, and VM signals.
 */
export function formatCompactForLLM(data: OverviewResponse): string {
  const lines: string[] = [];

  lines.push(
    `Metrics (${data.effective_since} window) — generated ${data.generated_at}`,
  );

  for (const cat of data.categories) {
    const nonEmpty = cat.metrics.filter((m) => m.groups.length > 0);
    if (nonEmpty.length === 0) continue;

    lines.push("");
    lines.push(`## ${cat.name}`);

    for (const m of nonEmpty) {
      const unitSuffix = m.unit ? ` (${m.unit})` : "";

      if (m.kind === "counter") {
        for (const g of m.groups) {
          lines.push(`- ${g.label ?? "total"}: ${g.count} events`);
        }
      } else {
        for (const g of m.groups) {
          const label = g.label ?? "all";
          const parts = [`${label}: n=${g.count}`];
          if (g.avg !== null) parts.push(`avg=${formatValue(g.avg, m.unit)}`);
          if (g.p95 !== null) parts.push(`p95=${formatValue(g.p95, m.unit)}`);
          if (g.max !== null) parts.push(`max=${formatValue(g.max, m.unit)}`);
          lines.push(`- ${parts.join(", ")}`);
        }
      }
    }
  }

  return lines.join("\n");
}
