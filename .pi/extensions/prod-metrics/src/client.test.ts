/**
 * Tests for the prod-metrics extension client.
 *
 * Covers URL construction, formatting, and response handling.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";

import {
  buildUrl,
  formatOverview,
  formatCompactForLLM,
  type OverviewResponse,
} from "./client.ts";

// ── URL construction ──────────────────────────────────────────────────────

describe("buildUrl", () => {
  it("constructs a basic URL with https default", () => {
    const url = buildUrl("example.com", "/api/v1/metrics/overview");
    assert.equal(url, "https://example.com/api/v1/metrics/overview");
  });

  it("preserves existing https scheme", () => {
    const url = buildUrl("https://example.com", "/api/v1/metrics/overview");
    assert.equal(url, "https://example.com/api/v1/metrics/overview");
  });

  it("uses http for localhost", () => {
    const url = buildUrl("localhost:4000", "/api/v1/metrics/overview");
    assert.equal(url, "http://localhost:4000/api/v1/metrics/overview");
  });

  it("strips trailing slashes from base", () => {
    const url = buildUrl("https://example.com/", "/api/v1/metrics/overview");
    assert.equal(url, "https://example.com/api/v1/metrics/overview");
  });

  it("appends query parameters", () => {
    const url = buildUrl("https://example.com", "/api/v1/metrics/overview", {
      since: "1h",
      categories: "http,oban",
    });
    assert.ok(url.includes("?since=1h"));
    assert.ok(url.includes("categories=http%2Coban"));
  });

  it("omits undefined and empty query parameters", () => {
    const url = buildUrl("https://example.com", "/api/v1/metrics/overview", {
      since: "1h",
      categories: "",
      top: "",
    });
    assert.ok(url.includes("?since=1h"));
    assert.ok(!url.includes("categories"));
    assert.ok(!url.includes("top"));
  });

  it("returns URL without query string when no params", () => {
    const url = buildUrl("https://example.com", "/api/v1/metrics/overview", {});
    assert.ok(!url.includes("?"));
  });
});

// ── Formatting ────────────────────────────────────────────────────────────

function makeOverview(
  overrides: Partial<OverviewResponse> = {},
): OverviewResponse {
  return {
    generated_at: "2026-06-18T10:00:00Z",
    requested_since: "1h",
    effective_since: "1h",
    since_time: 1_781_767_200_000_000,
    top: 10,
    top_clamped: false,
    categories: [],
    ...overrides,
  };
}

describe("formatOverview", () => {
  it("includes header with window and top info", () => {
    const data = makeOverview();
    const output = formatOverview(data);
    assert.ok(output.includes("1h window"));
    assert.ok(output.includes("top 10"));
    assert.ok(output.includes("Generated at 2026-06-18T10:00:00Z"));
  });

  it("notes clamping when top_clamped is true", () => {
    const data = makeOverview({ top_clamped: true });
    const output = formatOverview(data);
    assert.ok(output.includes("(clamped)"));
  });

  it("handles empty categories gracefully", () => {
    const data = makeOverview({ categories: [] });
    const output = formatOverview(data);
    assert.ok(output.includes("stale")); // footer note
    // Should not crash
    assert.ok(output.length > 0);
  });

  it("handles categories with empty metrics", () => {
    const data = makeOverview({
      categories: [
        {
          id: "http",
          name: "HTTP",
          metrics: [],
        },
      ],
    });
    const output = formatOverview(data);
    assert.ok(output.includes("HTTP"));
    assert.ok(output.includes("no matching metrics"));
  });

  it("renders timing summaries with correct formatting", () => {
    const data = makeOverview({
      categories: [
        {
          id: "http",
          name: "HTTP",
          metrics: [
            {
              key: "test:key",
              name: "router.duration",
              kind: "summary",
              unit: "millisecond",
              tags: ["route"],
              total_count: 3,
              groups: [
                {
                  label: "GET /collection",
                  count: 3,
                  latest: 18.4,
                  latest_at: "2026-06-18T09:59:58Z",
                  avg: 15.2,
                  max: 22.0,
                  p50: 14.1,
                  p95: 20.0,
                  p99: 21.5,
                },
              ],
            },
          ],
        },
      ],
    });
    const output = formatOverview(data);
    assert.ok(output.includes("router.duration"));
    assert.ok(output.includes("millisecond"));
    assert.ok(output.includes("GET /collection"));
    assert.ok(output.includes("n=3"));
    assert.ok(output.includes("avg="));
    assert.ok(output.includes("p95="));
  });

  it("renders counter summaries without timing stats", () => {
    const data = makeOverview({
      categories: [
        {
          id: "http",
          name: "HTTP",
          metrics: [
            {
              key: "test:counter",
              name: "errors.counter",
              kind: "counter",
              unit: null,
              tags: ["status"],
              total_count: 5,
              groups: [
                {
                  label: "500",
                  count: 3,
                  latest: null,
                  latest_at: "2026-06-18T09:59:58Z",
                  avg: null,
                  max: null,
                  p50: null,
                  p95: null,
                  p99: null,
                },
              ],
            },
          ],
        },
      ],
    });
    const output = formatOverview(data);
    assert.ok(output.includes("errors.counter"));
    assert.ok(output.includes("500: 3 events"));
    assert.ok(!output.includes("avg="));
  });

  it("renders no-data metrics gracefully", () => {
    const data = makeOverview({
      categories: [
        {
          id: "http",
          name: "HTTP",
          metrics: [
            {
              key: "test:empty",
              name: "empty.metric",
              kind: "summary",
              unit: "millisecond",
              tags: [],
              total_count: 0,
              groups: [],
            },
          ],
        },
      ],
    });
    const output = formatOverview(data);
    assert.ok(output.includes("empty.metric"));
    assert.ok(output.includes("no data in window"));
  });

  it("renders null label as (all)", () => {
    const data = makeOverview({
      categories: [
        {
          id: "vm",
          name: "VM",
          metrics: [
            {
              key: "test:vm",
              name: "vm.memory",
              kind: "summary",
              unit: "megabyte",
              tags: [],
              total_count: 2,
              groups: [
                {
                  label: null,
                  count: 2,
                  latest: 512,
                  latest_at: "2026-06-18T09:59:58Z",
                  avg: 384,
                  max: 512,
                  p50: 384,
                  p95: 512,
                  p99: 512,
                },
              ],
            },
          ],
        },
      ],
    });
    const output = formatOverview(data);
    assert.ok(output.includes("(all)"));
  });
});

describe("formatCompactForLLM", () => {
  it("includes window and generation time", () => {
    const data = makeOverview();
    const output = formatCompactForLLM(data);
    assert.ok(output.includes("Metrics (1h window)"));
    assert.ok(output.includes("generated"));
  });

  it("skips categories with no data", () => {
    const data = makeOverview({
      categories: [
        {
          id: "http",
          name: "HTTP",
          metrics: [
            {
              key: "test:empty",
              name: "empty.metric",
              kind: "summary",
              unit: null,
              tags: [],
              total_count: 0,
              groups: [],
            },
          ],
        },
        {
          id: "oban",
          name: "Oban",
          metrics: [
            {
              key: "test:oban",
              name: "oban.duration",
              kind: "summary",
              unit: "millisecond",
              tags: ["queue"],
              total_count: 5,
              groups: [
                {
                  label: "default",
                  count: 5,
                  latest: 120,
                  latest_at: "2026-06-18T09:59:58Z",
                  avg: 100,
                  max: 200,
                  p50: 95,
                  p95: 180,
                  p99: 195,
                },
              ],
            },
          ],
        },
      ],
    });
    const output = formatCompactForLLM(data);
    // HTTP should be skipped (no data)
    assert.ok(!output.includes("HTTP"));
    // Oban should appear
    assert.ok(output.includes("Oban"));
    assert.ok(output.includes("default"));
  });
});
