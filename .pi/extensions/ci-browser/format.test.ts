/**
 * Tests for format.ts — formatting, truncation, and time helpers.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  relativeTime,
  formatDuration,
  formatRunList,
  formatRunListCompact,
  formatRunDetail,
  formatRunDetailCompact,
  formatWatchProgress,
  formatWatchResult,
  formatFindResult,
  truncateText,
  formatTruncationNotice,
  type TruncationResult,
} from "./format.ts";
import type {
  RunListItem,
  RunDetail,
  PollState,
  PollResult,
  FindCurrentBranchResult,
} from "./ci-client.ts";

// ── Test fixtures ───────────────────────────────────────────────────────────

function fakeRun(overrides: Partial<RunListItem> = {}): RunListItem {
  return {
    attempt: 1,
    conclusion: "success",
    createdAt: "2026-06-01T10:00:00Z",
    databaseId: 12345,
    displayTitle: "Fix scrobble rule ordering",
    event: "push",
    headBranch: "main",
    headSha: "abc123def456789",
    name: "Test and Deploy",
    number: 42,
    startedAt: "2026-06-01T10:00:10Z",
    status: "completed",
    updatedAt: "2026-06-01T10:05:00Z",
    url: "https://github.com/owner/repo/actions/runs/12345",
    workflowDatabaseId: 99,
    workflowName: "Test and Deploy",
    ...overrides,
  };
}

function fakeDetail(overrides: Partial<RunListItem> = {}): RunDetail {
  return {
    ...fakeRun(overrides),
    jobs: [
      {
        databaseId: 1,
        name: "test",
        status: "completed",
        conclusion: "success",
        startedAt: "2026-06-01T10:00:10Z",
        completedAt: "2026-06-01T10:04:00Z",
        steps: [
          {
            name: "Checkout",
            status: "completed",
            conclusion: "success",
            number: 1,
            startedAt: "2026-06-01T10:00:10Z",
            completedAt: "2026-06-01T10:00:20Z",
          },
          {
            name: "Run tests",
            status: "completed",
            conclusion: "success",
            number: 2,
            startedAt: "2026-06-01T10:00:20Z",
            completedAt: "2026-06-01T10:03:50Z",
          },
        ],
      },
    ],
  };
}

// ── relativeTime ────────────────────────────────────────────────────────────

describe("relativeTime", () => {
  it("shows seconds for recent time", () => {
    const now = new Date();
    const iso = new Date(now.getTime() - 45_000).toISOString();
    assert.match(relativeTime(iso), /^\d+s ago$/);
  });

  it("shows minutes", () => {
    const now = new Date();
    const iso = new Date(now.getTime() - 5 * 60_000).toISOString();
    assert.match(relativeTime(iso), /^\d+m ago$/);
  });

  it("shows hours", () => {
    const now = new Date();
    const iso = new Date(now.getTime() - 3 * 3600_000).toISOString();
    assert.match(relativeTime(iso), /^\d+h ago$/);
  });

  it("shows days", () => {
    const now = new Date();
    const iso = new Date(now.getTime() - 2 * 86400_000).toISOString();
    assert.match(relativeTime(iso), /^\d+d ago$/);
  });

  it("shows months for old dates", () => {
    const iso = "2024-01-01T00:00:00Z";
    assert.match(relativeTime(iso), /^\d+mo ago$/);
  });
});

// ── formatDuration ──────────────────────────────────────────────────────────

describe("formatDuration", () => {
  it("formats milliseconds", () => {
    assert.equal(formatDuration(500), "500ms");
  });

  it("formats seconds", () => {
    assert.equal(formatDuration(45_000), "45s");
  });

  it("formats minutes and seconds", () => {
    assert.equal(formatDuration(185_000), "3m 5s");
  });

  it("formats hours and minutes", () => {
    assert.equal(formatDuration(3_660_000), "1h 1m");
  });
});

// ── formatRunList / formatRunListCompact ─────────────────────────────────────

describe("formatRunList", () => {
  it("returns 'No runs found' for empty array", () => {
    assert.equal(formatRunList([]), "No runs found.");
  });

  it("formats a run list with header", () => {
    const runs = [
      fakeRun(),
      fakeRun({ databaseId: 12346, headBranch: "feat/x" }),
    ];
    const output = formatRunList(runs);

    assert.ok(output.includes("2 run(s):"));
    assert.ok(output.includes("12345"));
    assert.ok(output.includes("12346"));
    assert.ok(output.includes("✓ PASS"));
    assert.ok(output.includes("Test and Deploy"));
    assert.ok(output.includes("main"));
    assert.ok(output.includes("feat/x"));
  });

  it("shows appropriate status for in_progress runs", () => {
    const runs = [fakeRun({ status: "in_progress", conclusion: null })];
    const output = formatRunList(runs);
    assert.ok(output.includes("RUNNING"));
  });

  it("shows FAIL for failed runs", () => {
    const runs = [fakeRun({ status: "completed", conclusion: "failure" })];
    const output = formatRunList(runs);
    assert.ok(output.includes("✗ FAIL"));
  });

  it("shows CANCEL for cancelled runs", () => {
    const runs = [fakeRun({ status: "completed", conclusion: "cancelled" })];
    const output = formatRunList(runs);
    assert.ok(output.includes("○ CANCEL"));
  });

  it("truncates long fields to fit column widths", () => {
    const runs = [
      fakeRun({
        workflowName: "A very long workflow name that exceeds limits",
        headBranch: "feature/a-very-long-branch-name",
        displayTitle:
          "This is a very long display title that should be truncated",
      }),
    ];
    const output = formatRunList(runs);
    // Workflow column is 26 chars max
    const lines = output.split("\n");
    const dataLine = lines[lines.length - 1];
    const parts = dataLine.split("│");
    assert.ok(parts.length >= 5);
  });
});

describe("formatRunListCompact", () => {
  it("formats runs in single-line mode", () => {
    const runs = [fakeRun()];
    const output = formatRunListCompact(runs);

    assert.ok(output.includes("#12345"));
    assert.ok(output.includes("✓ PASS"));
    assert.ok(output.includes("Test and Deploy"));
    assert.ok(output.includes("main@abc123d"));
  });

  it("shows age", () => {
    const runs = [fakeRun()];
    const output = formatRunListCompact(runs);
    assert.match(output, /\d+\w ago/);
  });
});

// ── formatRunDetail / formatRunDetailCompact ────────────────────────────────

describe("formatRunDetail", () => {
  it("renders full detail with jobs and steps", () => {
    const detail = fakeDetail();
    const output = formatRunDetail(detail);

    assert.ok(output.includes("✓ PASS"));
    assert.ok(output.includes("Test and Deploy"));
    assert.ok(output.includes("#12345"));
    assert.ok(output.includes("main"));
    assert.ok(output.includes("abc123d"));
    assert.ok(output.includes("push"));
    assert.ok(output.includes("Checkout"));
    assert.ok(output.includes("Run tests"));
    assert.ok(output.includes("/actions/runs/12345"));
  });

  it("shows attempt when > 1", () => {
    const detail = fakeDetail({ attempt: 3 });
    const output = formatRunDetail(detail);
    assert.ok(output.includes("Attempt:  3"));
  });

  it("hides attempt when == 1", () => {
    const detail = fakeDetail({ attempt: 1 });
    const output = formatRunDetail(detail);
    assert.ok(!output.includes("Attempt:"));
  });

  it("includes failed log when provided", () => {
    const detail = fakeDetail();
    const output = formatRunDetail(detail, "Error line 1\nError line 2");

    assert.ok(output.includes("FAILED LOG:"));
    assert.ok(output.includes("Error line 1"));
  });

  it("shows 'No job information available' when jobs empty", () => {
    const detail = { ...fakeDetail(), jobs: [] };
    const output = formatRunDetail(detail);
    assert.ok(output.includes("No job information available."));
  });

  it("renders job steps with conclusion labels", () => {
    const detail = fakeDetail();
    detail.jobs[0].steps[1].conclusion = "failure";
    const output = formatRunDetail(detail);

    // Should show FAIL for the failed step, PASS for the successful one
    assert.ok(output.includes("✗ FAIL"));
    assert.ok(output.includes("✓ PASS"));
  });
});

describe("formatRunDetailCompact", () => {
  it("renders a single-line summary with jobs", () => {
    const detail = fakeDetail();
    const output = formatRunDetailCompact(detail);

    assert.ok(output.includes("✓ PASS"));
    assert.ok(output.includes("#12345"));
    assert.ok(output.includes("main@abc123d"));
    assert.ok(output.includes("push"));
    assert.ok(output.includes("/actions/runs/12345"));
    assert.ok(output.includes("test"));
  });

  it("shows failed step count for failed jobs", () => {
    const detail = fakeDetail();
    detail.jobs[0].steps[1].conclusion = "failure";
    detail.jobs[0].conclusion = "failure";

    const output = formatRunDetailCompact(detail);
    assert.ok(output.includes("[1 failed]"));
  });
});

// ── formatWatchProgress ─────────────────────────────────────────────────────

describe("formatWatchProgress", () => {
  it("renders progress snapshot", () => {
    const state: PollState = {
      run: fakeDetail({ status: "in_progress", conclusion: null }),
      pollCount: 5,
      elapsedMs: 50_000,
    };

    const output = formatWatchProgress(state);
    assert.ok(output.includes("RUNNING"));
    assert.ok(output.includes("#12345"));
    assert.ok(output.includes("poll #5"));
    assert.ok(output.includes("50s"));
  });
});

// ── formatWatchResult ───────────────────────────────────────────────────────

describe("formatWatchResult", () => {
  it("renders completed result", () => {
    const result: PollResult = {
      run: fakeDetail(),
      pollCount: 10,
      elapsedMs: 100_000,
      timedOut: false,
      cancelled: false,
    };

    const output = formatWatchResult(result, {
      intervalMs: 10_000,
      timeoutMs: 1_800_000,
    });

    assert.ok(output.includes("completed"));
    assert.ok(output.includes("✓ PASS"));
    assert.ok(output.includes("Polls: 10"));
    assert.ok(output.includes("Interval: 10s"));
  });

  it("renders cancelled result", () => {
    const result: PollResult = {
      run: fakeDetail({ status: "in_progress", conclusion: null }),
      pollCount: 3,
      elapsedMs: 30_000,
      timedOut: false,
      cancelled: true,
    };

    const output = formatWatchResult(result, {
      intervalMs: 10_000,
      timeoutMs: 1_800_000,
    });

    assert.ok(output.includes("cancelled"));
    assert.ok(output.includes("30s"));
  });

  it("renders timed-out result", () => {
    const result: PollResult = {
      run: fakeDetail({ status: "in_progress", conclusion: null }),
      pollCount: 180,
      elapsedMs: 1_800_000,
      timedOut: true,
      cancelled: false,
    };

    const output = formatWatchResult(result, {
      intervalMs: 10_000,
      timeoutMs: 1_800_000,
    });

    assert.ok(output.includes("timed out"));
    assert.ok(output.includes("30m 0s"));
  });
});

// ── formatFindResult ────────────────────────────────────────────────────────

describe("formatFindResult", () => {
  it("renders watchable result", () => {
    const result: FindCurrentBranchResult = {
      type: "watchable",
      run: fakeDetail({ status: "in_progress", conclusion: null }),
      latestCompleted: null,
      headShaDiffers: false,
    };

    const output = formatFindResult(result);
    assert.ok(output.includes("HEAD match"));
    assert.ok(output.includes("#12345"));
  });

  it("renders branch_fallback with SHA note", () => {
    const result: FindCurrentBranchResult = {
      type: "branch_fallback",
      run: fakeDetail({ status: "in_progress", conclusion: null }),
      latestCompleted: null,
      headShaDiffers: true,
    };

    const output = formatFindResult(result);
    assert.ok(output.includes("SHA differs"));
  });

  it("renders no_active_run with latest completed", () => {
    const result: FindCurrentBranchResult = {
      type: "no_active_run",
      run: null,
      latestCompleted: fakeRun({ databaseId: 110 }),
      headShaDiffers: false,
    };

    const output = formatFindResult(result);
    assert.ok(output.includes("No active/watchable run"));
    assert.ok(output.includes("Latest completed run:"));
    assert.ok(output.includes("#110"));
  });

  it("renders no_active_run without latest completed", () => {
    const result: FindCurrentBranchResult = {
      type: "no_active_run",
      run: null,
      latestCompleted: null,
      headShaDiffers: false,
    };

    const output = formatFindResult(result);
    assert.ok(output.includes("No active/watchable run"));
    assert.ok(!output.includes("Latest completed"));
  });
});

// ── truncateText / formatTruncationNotice ────────────────────────────────────

describe("truncateText", () => {
  it("returns unchanged for small text", () => {
    const text = "hello world";
    const result = truncateText(text);
    assert.equal(result.truncated, false);
    assert.equal(result.content, text);
    assert.equal(result.outputLines, 1);
  });

  it("truncates by byte limit", () => {
    const text = "a".repeat(60_000);
    const result = truncateText(text, 100);
    assert.equal(result.truncated, true);
    assert.ok(result.content.length < text.length);
  });

  it("truncates by line limit and keeps tail", () => {
    const lines = Array.from({ length: 3000 }, (_, i) => `line ${i}`);
    const text = lines.join("\n");
    const result = truncateText(text, 50_000, 100); // max 100 lines

    assert.equal(result.truncated, true);
    const outputLines = result.content.split("\n");
    assert.ok(outputLines.length <= 100);
  });

  it("handles multi-byte characters", () => {
    const text = "🚀".repeat(100);
    const result = truncateText(text, 50);
    assert.equal(result.truncated, true);
    assert.ok(Buffer.byteLength(result.content, "utf-8") <= 50);
  });
});

describe("formatTruncationNotice", () => {
  it("returns empty string when not truncated", () => {
    const result: TruncationResult = {
      content: "hello",
      truncated: false,
      totalLines: 1,
      outputLines: 1,
      totalBytes: 5,
      outputBytes: 5,
    };
    assert.equal(formatTruncationNotice(result), "");
  });

  it("returns notice when truncated", () => {
    const result: TruncationResult = {
      content: "truncated...",
      truncated: true,
      totalLines: 1000,
      outputLines: 500,
      totalBytes: 100_000,
      outputBytes: 50_000,
    };
    const notice = formatTruncationNotice(result);
    assert.ok(notice.includes("truncated"));
    assert.ok(notice.includes("48.8KB"));
    assert.ok(notice.includes("97.7KB"));
    assert.ok(notice.includes("500 of 1000"));
  });
});
