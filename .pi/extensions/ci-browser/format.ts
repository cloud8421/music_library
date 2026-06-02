/**
 * Format helpers — convert structured CI data into concise text for LLM tools
 * and TUI display.
 *
 * Pure functions with no side effects or pi package imports.
 */

import type {
  RunListItem,
  RunDetail,
  Job,
  Step,
  PollState,
  PollResult,
  FindCurrentBranchResult,
} from "./ci-client.ts";

// ── Status/conclusion labels ────────────────────────────────────────────────

const STATUS_LABELS: Record<string, string> = {
  queued: "QUEUED",
  in_progress: "RUNNING",
  requested: "QUEUED",
  waiting: "WAITING",
  pending: "PENDING",
  completed: "DONE",
};

const CONCLUSION_LABELS: Record<string, string> = {
  success: "✓ PASS",
  failure: "✗ FAIL",
  cancelled: "○ CANCEL",
  skipped: "— SKIP",
  timed_out: "⏱ TIMEOUT",
  startup_failure: "✗ STARTUP",
  action_required: "⚠ ACTION",
  neutral: "— NEUTRAL",
  stale: "— STALE",
};

function statusLabel(run: RunListItem): string {
  if (run.status === "completed" && run.conclusion) {
    return CONCLUSION_LABELS[run.conclusion] ?? run.conclusion.toUpperCase();
  }
  return STATUS_LABELS[run.status] ?? run.status.toUpperCase();
}

// ── Time formatting ─────────────────────────────────────────────────────────

export function relativeTime(isoString: string): string {
  const now = Date.now();
  const then = new Date(isoString).getTime();
  const diffMs = now - then;
  const diffSec = Math.floor(diffMs / 1000);

  if (diffSec < 60) return `${diffSec}s ago`;
  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `${diffHr}h ago`;
  const diffDay = Math.floor(diffHr / 24);
  if (diffDay < 30) return `${diffDay}d ago`;
  const diffMonth = Math.floor(diffDay / 30);
  return `${diffMonth}mo ago`;
}

export function formatDuration(ms: number): string {
  if (ms < 1000) return `${ms}ms`;
  const sec = Math.floor(ms / 1000);
  if (sec < 60) return `${sec}s`;
  const min = Math.floor(sec / 60);
  const remainSec = sec % 60;
  if (min < 60) return `${min}m ${remainSec}s`;
  const hr = Math.floor(min / 60);
  const remainMin = min % 60;
  return `${hr}h ${remainMin}m`;
}

export function formatDateTime(isoString: string): string {
  const d = new Date(isoString);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

function shortSha(sha: string): string {
  return sha.slice(0, 7);
}

// ── Run list formatting ─────────────────────────────────────────────────────

export function formatRunList(runs: RunListItem[]): string {
  if (runs.length === 0) return "No runs found.";

  const lines: string[] = [
    `${runs.length} run(s):`,
    "",
    "ID       │ Status   │ Workflow                   │ Branch         │ Title",
    "─────────┼──────────┼────────────────────────────┼────────────────┼──────────────────────────────────",
  ];

  for (const run of runs) {
    const id = String(run.databaseId).padEnd(8);
    const status = statusLabel(run).padEnd(8);
    const workflow = (run.workflowName || run.name).slice(0, 26).padEnd(26);
    const branch = run.headBranch.slice(0, 14).padEnd(14);
    const title = run.displayTitle.slice(0, 32).padEnd(32);

    lines.push(`${id} │ ${status} │ ${workflow} │ ${branch} │ ${title}`);
  }

  return lines.join("\n");
}

export function formatRunListCompact(runs: RunListItem[]): string {
  if (runs.length === 0) return "No runs found.";

  const lines: string[] = [];
  for (const run of runs) {
    const age = relativeTime(run.createdAt);
    const id = `#${run.databaseId}`;
    const label = statusLabel(run);
    const workflow = run.workflowName || run.name;
    const sha = shortSha(run.headSha);

    lines.push(
      `${id.padEnd(12)} ${label.padEnd(10)} ${workflow.padEnd(28)} ${run.headBranch}@${sha}  ${age}  ${run.displayTitle}`,
    );
  }

  return lines.join("\n");
}

// ── Run detail formatting ───────────────────────────────────────────────────

function formatStep(step: Step): string {
  const status = step.conclusion
    ? (CONCLUSION_LABELS[step.conclusion] ?? step.conclusion)
    : (STATUS_LABELS[step.status] ?? step.status);

  let line = `  ${status.padEnd(10)} ${step.number}. ${step.name}`;

  if (step.startedAt && step.completedAt) {
    const start = new Date(step.startedAt).getTime();
    const end = new Date(step.completedAt).getTime();
    line += `  (${formatDuration(end - start)})`;
  }

  return line;
}

function formatJob(job: Job): string {
  const status = job.conclusion
    ? (CONCLUSION_LABELS[job.conclusion] ?? job.conclusion)
    : (STATUS_LABELS[job.status] ?? job.status);

  const lines: string[] = [`  ${status}  ${job.name}`];

  if (job.steps.length > 0) {
    for (const step of job.steps) {
      lines.push(formatStep(step));
    }
  }

  return lines.join("\n");
}

export function formatRunDetail(run: RunDetail, failedLog?: string): string {
  const lines: string[] = [];

  // Header
  const conclusion = statusLabel(run);
  lines.push(
    `${conclusion}  ${run.workflowName || run.name}  #${run.databaseId}`,
  );
  lines.push("");

  // Metadata
  lines.push(`Title:    ${run.displayTitle}`);
  lines.push(`Branch:   ${run.headBranch}  (${shortSha(run.headSha)})`);
  lines.push(`Event:    ${run.event}`);
  lines.push(
    `Created:  ${formatDateTime(run.createdAt)}  (${relativeTime(run.createdAt)})`,
  );
  if (run.startedAt) {
    lines.push(`Started:  ${formatDateTime(run.startedAt)}`);
  }
  lines.push(`Updated:  ${formatDateTime(run.updatedAt)}`);
  if (run.attempt > 1) {
    lines.push(`Attempt:  ${run.attempt}`);
  }
  lines.push(`URL:      ${run.url}`);
  lines.push("");

  // Jobs
  if (run.jobs.length > 0) {
    lines.push(`Jobs (${run.jobs.length}):`);
    for (const job of run.jobs) {
      lines.push(formatJob(job));
    }
  } else {
    lines.push("No job information available.");
  }

  // Failed log
  if (failedLog) {
    lines.push("");
    lines.push("─".repeat(60));
    lines.push("FAILED LOG:");
    lines.push("─".repeat(60));
    lines.push(failedLog);
  }

  return lines.join("\n");
}

export function formatRunDetailCompact(run: RunDetail): string {
  const conclusion = statusLabel(run);
  const lines: string[] = [
    `${conclusion}  ${run.workflowName || run.name}  #${run.databaseId}`,
    `Branch: ${run.headBranch}@${shortSha(run.headSha)}  Event: ${run.event}  Created: ${relativeTime(run.createdAt)}`,
    `URL: ${run.url}`,
  ];

  // Job summary
  if (run.jobs.length > 0) {
    const jobSummaries = run.jobs.map((j) => {
      const label = j.conclusion
        ? (CONCLUSION_LABELS[j.conclusion] ?? j.conclusion)
        : (STATUS_LABELS[j.status] ?? j.status);
      const failCount = j.steps.filter(
        (s) => s.conclusion === "failure",
      ).length;
      const failNote = failCount > 0 ? ` [${failCount} failed]` : "";
      return `  ${label}  ${j.name}${failNote}`;
    });
    lines.push(...jobSummaries);
  }

  return lines.join("\n");
}

// ── Watch progress formatting ───────────────────────────────────────────────

export function formatWatchProgress(state: PollState): string {
  const run = state.run;
  const label = statusLabel(run);
  return (
    `${label}  #${run.databaseId}  ${run.workflowName}  ` +
    `poll #${state.pollCount}  ${formatDuration(state.elapsedMs)}`
  );
}

export function formatWatchResult(
  result: PollResult,
  opts: { intervalMs: number; timeoutMs: number },
): string {
  const run = result.run;
  const conclusion = statusLabel(run);
  const lines: string[] = [];

  if (result.cancelled) {
    lines.push(`Watch cancelled after ${formatDuration(result.elapsedMs)}.`);
  } else if (result.timedOut) {
    lines.push(
      `Watch timed out after ${formatDuration(result.elapsedMs)} ` +
        `(timeout: ${formatDuration(opts.timeoutMs)}). ` +
        `Last known status: ${conclusion}`,
    );
  } else {
    lines.push(
      `Run completed in ${formatDuration(result.elapsedMs)}: ${conclusion}`,
    );
  }

  lines.push(
    `Polls: ${result.pollCount}  Interval: ${formatDuration(opts.intervalMs)}`,
  );
  lines.push("");

  // Always include the final run detail compact
  lines.push(formatRunDetailCompact(run));

  return lines.join("\n");
}

// ── Current branch result formatting ────────────────────────────────────────

export function formatFindResult(result: FindCurrentBranchResult): string {
  const lines: string[] = [];

  switch (result.type) {
    case "watchable":
      lines.push("Found watchable run for current branch (HEAD match):");
      lines.push("");
      lines.push(formatRunDetailCompact(result.run!));
      break;

    case "branch_fallback": {
      const shaNote = result.headShaDiffers
        ? " (SHA differs from current HEAD)"
        : "";
      lines.push(
        `Found watchable run for current branch${shaNote} (HEAD had no active run):`,
      );
      lines.push("");
      lines.push(formatRunDetailCompact(result.run!));
      break;
    }

    case "no_active_run": {
      lines.push("No active/watchable run found for the current branch.");
      if (result.latestCompleted) {
        lines.push("");
        lines.push("Latest completed run:");
        lines.push(formatRunListCompact([result.latestCompleted]));
      }
      break;
    }
  }

  return lines.join("\n");
}

// ── Truncation helpers (local, pi-independent) ──────────────────────────────

export interface TruncationResult {
  content: string;
  truncated: boolean;
  totalLines: number;
  outputLines: number;
  totalBytes: number;
  outputBytes: number;
}

export function truncateText(
  text: string,
  maxBytes: number = 50_000,
  maxLines: number = 2_000,
): TruncationResult {
  const totalBytes = Buffer.byteLength(text, "utf-8");
  const allLines = text.split("\n");
  const totalLines = allLines.length;

  // No truncation needed
  if (totalBytes <= maxBytes && totalLines <= maxLines) {
    return {
      content: text,
      truncated: false,
      totalLines,
      outputLines: totalLines,
      totalBytes,
      outputBytes: totalBytes,
    };
  }

  if (maxBytes <= 0 || maxLines <= 0) {
    return {
      content: "",
      truncated: true,
      totalLines,
      outputLines: 0,
      totalBytes,
      outputBytes: 0,
    };
  }

  // Truncate lines first
  let lines = allLines;
  if (lines.length > maxLines) {
    // Keep tail for log output (most recent content is usually at the end)
    lines = lines.slice(-maxLines);
  }

  // Build output, stopping at byte limit. If the first retained line alone is
  // larger than the byte budget, preserve a valid UTF-8 prefix instead of
  // dropping the whole log body.
  const outputLines: string[] = [];
  let outputBytes = 0;

  for (const line of lines) {
    const separator = outputLines.length > 0 ? "\n" : "";
    const lineWithSeparator = separator + line;
    const lineBytes = Buffer.byteLength(lineWithSeparator, "utf-8");

    if (outputBytes + lineBytes <= maxBytes) {
      outputLines.push(line);
      outputBytes += lineBytes;
      continue;
    }

    const remainingBytes =
      maxBytes - outputBytes - Buffer.byteLength(separator, "utf-8");

    if (remainingBytes > 0) {
      const partialLine = takeUtf8Prefix(line, remainingBytes);
      if (partialLine) {
        outputLines.push(partialLine);
        outputBytes +=
          Buffer.byteLength(separator, "utf-8") +
          Buffer.byteLength(partialLine, "utf-8");
      }
    }

    break;
  }

  const content = outputLines.join("\n");

  return {
    content,
    truncated: true,
    totalLines,
    outputLines: outputLines.length,
    totalBytes,
    outputBytes: Buffer.byteLength(content, "utf-8"),
  };
}

function takeUtf8Prefix(text: string, maxBytes: number): string {
  let result = "";
  let bytes = 0;

  for (const char of text) {
    const charBytes = Buffer.byteLength(char, "utf-8");
    if (bytes + charBytes > maxBytes) break;

    result += char;
    bytes += charBytes;
  }

  return result;
}

export function formatTruncationNotice(result: TruncationResult): string {
  if (!result.truncated) return "";

  const bytesNote =
    result.outputBytes < result.totalBytes
      ? ` (${formatBytes(result.outputBytes)} of ${formatBytes(result.totalBytes)})`
      : "";
  const linesNote =
    result.outputLines < result.totalLines
      ? `, ${result.outputLines} of ${result.totalLines} lines`
      : "";

  return (
    `\n\n[Output truncated${bytesNote}${linesNote}. ` +
    `Use ci_view_run with includeFailedLog or the gh CLI for full output.]`
  );
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes}B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
}
