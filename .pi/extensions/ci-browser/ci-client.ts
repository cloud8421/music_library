/**
 * CI Client — typed helper layer around `gh` and `git` CLI commands.
 *
 * All functions accept an injected `ExecFn` so unit tests can substitute fake
 * `gh`/`git` output without network access, `gh` installation, or
 * authentication.
 */

// ── Exec abstraction ────────────────────────────────────────────────────────

export interface ExecResult {
  stdout: string;
  stderr: string;
  code: number;
  killed: boolean;
}

export interface ExecOptions {
  signal?: AbortSignal;
  timeout?: number;
}

export type ExecFn = (
  command: string,
  args: string[],
  options?: ExecOptions,
) => Promise<ExecResult>;

// ── Type definitions ────────────────────────────────────────────────────────

export interface RunListItem {
  attempt: number;
  conclusion: string | null;
  createdAt: string;
  databaseId: number;
  displayTitle: string;
  event: string;
  headBranch: string;
  headSha: string;
  name: string;
  number: number;
  startedAt: string;
  status: string;
  updatedAt: string;
  url: string;
  workflowDatabaseId: number;
  workflowName: string;
}

export interface Step {
  name: string;
  status: string;
  conclusion: string | null;
  number: number;
  startedAt: string | null;
  completedAt: string | null;
}

export interface Job {
  databaseId: number;
  name: string;
  status: string;
  conclusion: string | null;
  startedAt: string;
  completedAt: string | null;
  steps: Step[];
}

export interface RunDetail extends RunListItem {
  jobs: Job[];
}

export interface RepoContext {
  branch: string;
  headSha: string;
}

export interface PollState {
  run: RunDetail;
  pollCount: number;
  elapsedMs: number;
}

export interface PollResult {
  run: RunDetail;
  pollCount: number;
  elapsedMs: number;
  timedOut: boolean;
  cancelled: boolean;
}

export interface FindCurrentBranchResult {
  type: "watchable" | "branch_fallback" | "no_active_run";
  run: RunDetail | null;
  latestCompleted: RunListItem | null;
  headShaDiffers: boolean;
}

// ── Run list JSON fields for gh --json ──────────────────────────────────────

const RUN_LIST_FIELDS = [
  "attempt",
  "conclusion",
  "createdAt",
  "databaseId",
  "displayTitle",
  "event",
  "headBranch",
  "headSha",
  "name",
  "number",
  "startedAt",
  "status",
  "updatedAt",
  "url",
  "workflowDatabaseId",
  "workflowName",
].join(",");

const RUN_VIEW_FIELDS = [
  "attempt",
  "conclusion",
  "createdAt",
  "databaseId",
  "displayTitle",
  "event",
  "headBranch",
  "headSha",
  "jobs",
  "name",
  "number",
  "startedAt",
  "status",
  "updatedAt",
  "url",
  "workflowDatabaseId",
  "workflowName",
].join(",");

// ── Constants ───────────────────────────────────────────────────────────────

const WATCHABLE_STATUSES = new Set([
  "queued",
  "in_progress",
  "requested",
  "waiting",
  "pending",
]);

const TERMINAL_CONCLUSIONS = new Set([
  "success",
  "failure",
  "cancelled",
  "skipped",
  "timed_out",
  "startup_failure",
  "action_required",
  "neutral",
  "stale",
]);

// ── Error classes ───────────────────────────────────────────────────────────

export class GhNotFoundError extends Error {
  constructor() {
    super("gh CLI not found. Install the GitHub CLI: https://cli.github.com/");
    this.name = "GhNotFoundError";
  }
}

export class GhAuthError extends Error {
  constructor() {
    super(
      "gh is not authenticated. Run `gh auth login` or set GH_TOKEN / GITHUB_TOKEN.",
    );
    this.name = "GhAuthError";
  }
}

export class NotAGitRepoError extends Error {
  constructor() {
    super("Not in a git repository. Run /ci from within a git repo.");
    this.name = "NotAGitRepoError";
  }
}

export class InvalidRunIdError extends Error {
  constructor(runId: string | number) {
    super(`Invalid or unknown run ID: ${runId}`);
    this.name = "InvalidRunIdError";
  }
}

export class JsonParseError extends Error {
  constructor(details: string) {
    super(`Failed to parse gh JSON output: ${details}`);
    this.name = "JsonParseError";
  }
}

export class GhCommandError extends Error {
  constructor(command: string, code: number, stderr: string) {
    super(
      `gh command failed: ${command} (exit code ${code})${stderr ? `: ${stderr}` : ""}`,
    );
    this.name = "GhCommandError";
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function parseGhJson<T>(stdout: string): T {
  try {
    return JSON.parse(stdout) as T;
  } catch (err) {
    throw new JsonParseError(String(err));
  }
}

function checkGhInstalled(stderr: string, code: number): void {
  if (code !== 0 && stderr.toLowerCase().includes("command not found")) {
    throw new GhNotFoundError();
  }
}

function checkGhAuth(stderr: string, code: number): void {
  if (
    code !== 0 &&
    (stderr.toLowerCase().includes("not authenticated") ||
      stderr.toLowerCase().includes("authentication required"))
  ) {
    throw new GhAuthError();
  }
}

function checkInvalidRun(stderr: string, code: number, runId: number): void {
  if (
    code !== 0 &&
    (stderr.toLowerCase().includes("not found") ||
      stderr.toLowerCase().includes("no run") ||
      stderr.toLowerCase().includes("could not find"))
  ) {
    throw new InvalidRunIdError(runId);
  }
}

function normalizeCliError(
  command: string,
  result: ExecResult,
  runId?: number,
): void {
  if (result.code === 0) return;

  checkGhInstalled(result.stderr, result.code);
  checkGhAuth(result.stderr, result.code);
  if (runId !== undefined) {
    checkInvalidRun(result.stderr, result.code, runId);
  }

  throw new GhCommandError(command, result.code, result.stderr);
}

function isWatchable(run: RunListItem): boolean {
  return WATCHABLE_STATUSES.has(run.status);
}

function isTerminal(run: RunDetail): boolean {
  return run.status === "completed" && run.conclusion !== null;
}

function abortableSleep(ms: number, signal: AbortSignal): Promise<void> {
  if (ms <= 0) return Promise.resolve();

  return new Promise((resolve) => {
    const onAbort = () => {
      clearTimeout(timer);
      signal.removeEventListener("abort", onAbort);
      resolve();
    };

    const timer = setTimeout(() => {
      signal.removeEventListener("abort", onAbort);
      resolve();
    }, ms);

    signal.addEventListener("abort", onAbort, { once: true });
  });
}

// ── Client factory ──────────────────────────────────────────────────────────

export interface ListRunsOptions {
  limit?: number;
  branch?: string;
  commit?: string;
  status?: string;
  workflow?: string;
}

export interface ViewRunOptions {
  attempt?: number;
}

export interface PollOptions {
  intervalMs?: number;
  timeoutMs?: number;
  now?: () => number;
  sleep?: (ms: number, signal: AbortSignal) => Promise<void>;
}

export interface CiClient {
  currentRepoContext(): Promise<RepoContext>;
  listRuns(opts?: ListRunsOptions): Promise<RunListItem[]>;
  viewRun(runId: number, opts?: ViewRunOptions): Promise<RunDetail>;
  viewRunFailedLog(runId: number): Promise<string>;
  findCurrentBranchRun(): Promise<FindCurrentBranchResult>;
  pollRunUntilDone(
    runId: number,
    opts: PollOptions,
    signal: AbortSignal,
    onUpdate?: (state: PollState) => void,
  ): Promise<PollResult>;
}

export function createCiClient(exec: ExecFn): CiClient {
  // ── currentRepoContext ──────────────────────────────────────────────────

  async function currentRepoContext(): Promise<RepoContext> {
    const gitResult = await exec("git", ["rev-parse", "--is-inside-work-tree"]);

    if (gitResult.code !== 0) {
      throw new NotAGitRepoError();
    }

    const [branchResult, shaResult] = await Promise.all([
      exec("git", ["branch", "--show-current"]),
      exec("git", ["rev-parse", "HEAD"]),
    ]);

    if (branchResult.code !== 0 || shaResult.code !== 0) {
      throw new NotAGitRepoError();
    }

    const branch = branchResult.stdout.trim();
    const headSha = shaResult.stdout.trim();

    // Detached HEAD — branch will be empty string
    if (!headSha) {
      throw new NotAGitRepoError();
    }

    return { branch: branch || "(detached HEAD)", headSha };
  }

  // ── listRuns ────────────────────────────────────────────────────────────

  async function listRuns(opts: ListRunsOptions = {}): Promise<RunListItem[]> {
    const limit = Math.min(Math.max(opts.limit ?? 20, 1), 100);
    const args = [
      "run",
      "list",
      "--json",
      RUN_LIST_FIELDS,
      "--limit",
      String(limit),
    ];

    if (opts.branch) args.push("--branch", opts.branch);
    if (opts.commit) args.push("--commit", opts.commit);
    if (opts.status) args.push("--status", opts.status);
    if (opts.workflow) args.push("--workflow", opts.workflow);

    const result = await exec("gh", args);
    normalizeCliError("gh run list", result);
    return parseGhJson<RunListItem[]>(result.stdout);
  }

  // ── viewRun ─────────────────────────────────────────────────────────────

  async function viewRun(
    runId: number,
    opts: ViewRunOptions = {},
  ): Promise<RunDetail> {
    const args = ["run", "view", String(runId), "--json", RUN_VIEW_FIELDS];

    if (opts.attempt !== undefined) {
      args.push("--attempt", String(opts.attempt));
    }

    const result = await exec("gh", args);
    normalizeCliError("gh run view", result, runId);
    return parseGhJson<RunDetail>(result.stdout);
  }

  // ── viewRunFailedLog ────────────────────────────────────────────────────

  async function viewRunFailedLog(runId: number): Promise<string> {
    const result = await exec("gh", [
      "run",
      "view",
      String(runId),
      "--log-failed",
    ]);
    normalizeCliError("gh run view --log-failed", result, runId);
    return result.stdout;
  }

  // ── findCurrentBranchRun ────────────────────────────────────────────────

  async function findCurrentBranchRun(): Promise<FindCurrentBranchResult> {
    const ctx = await currentRepoContext();
    const { branch, headSha } = ctx;

    // 1. Try current branch + current HEAD SHA
    if (branch !== "(detached HEAD)" && headSha) {
      const headRuns = await listRuns({
        branch,
        commit: headSha,
        limit: 30,
      });

      const watchableHead = headRuns.find(isWatchable);
      if (watchableHead) {
        const run = await viewRun(watchableHead.databaseId);
        return {
          type: "watchable",
          run,
          latestCompleted:
            headRuns.find((r) => r.status === "completed") ?? null,
          headShaDiffers: false,
        };
      }

      // 2. Try all branch runs
      const branchRuns = await listRuns({ branch, limit: 30 });
      const watchableBranch = branchRuns.find(isWatchable);

      if (watchableBranch) {
        const run = await viewRun(watchableBranch.databaseId);
        return {
          type: "branch_fallback",
          run,
          latestCompleted:
            branchRuns.find((r) => r.status === "completed") ?? null,
          headShaDiffers: watchableBranch.headSha !== headSha,
        };
      }
    }

    // 3. No active run — return latest completed as context
    let latestCompleted: RunListItem | null = null;
    if (branch !== "(detached HEAD)") {
      const branchRuns = await listRuns({ branch, limit: 10 });
      latestCompleted =
        branchRuns.find((r) => r.status === "completed") ?? null;
    }

    return {
      type: "no_active_run",
      run: null,
      latestCompleted,
      headShaDiffers: false,
    };
  }

  // ── pollRunUntilDone ────────────────────────────────────────────────────

  async function pollRunUntilDone(
    runId: number,
    opts: PollOptions,
    signal: AbortSignal,
    onUpdate?: (state: PollState) => void,
  ): Promise<PollResult> {
    const intervalMs = Math.min(
      Math.max(opts.intervalMs ?? 10_000, 5_000),
      60_000,
    );
    const timeoutMs = Math.min(
      Math.max(opts.timeoutMs ?? 1_800_000, 30_000),
      3_600_000,
    );

    const now = opts.now ?? Date.now;
    const sleep = opts.sleep ?? abortableSleep;
    const startTime = now();
    let pollCount = 0;

    function elapsed(): number {
      return now() - startTime;
    }

    function buildState(run: RunDetail): PollState {
      return { run, pollCount, elapsedMs: elapsed() };
    }

    // Initial fetch
    if (signal.aborted) {
      const run = await viewRun(runId);
      return {
        run,
        pollCount: 0,
        elapsedMs: elapsed(),
        timedOut: false,
        cancelled: true,
      };
    }

    let run = await viewRun(runId);
    pollCount++;
    onUpdate?.(buildState(run));

    if (isTerminal(run)) {
      return {
        run,
        pollCount,
        elapsedMs: elapsed(),
        timedOut: false,
        cancelled: false,
      };
    }

    // Poll loop
    while (true) {
      if (signal.aborted) {
        return {
          run,
          pollCount,
          elapsedMs: elapsed(),
          timedOut: false,
          cancelled: true,
        };
      }

      const remainingMs = timeoutMs - elapsed();
      if (remainingMs <= 0) {
        return {
          run,
          pollCount,
          elapsedMs: elapsed(),
          timedOut: true,
          cancelled: false,
        };
      }

      await sleep(Math.min(intervalMs, remainingMs), signal);

      if (signal.aborted) {
        return {
          run,
          pollCount,
          elapsedMs: elapsed(),
          timedOut: false,
          cancelled: true,
        };
      }

      if (elapsed() >= timeoutMs) {
        return {
          run,
          pollCount,
          elapsedMs: elapsed(),
          timedOut: true,
          cancelled: false,
        };
      }

      run = await viewRun(runId);
      pollCount++;
      onUpdate?.(buildState(run));

      if (isTerminal(run)) {
        return {
          run,
          pollCount,
          elapsedMs: elapsed(),
          timedOut: false,
          cancelled: false,
        };
      }
    }
  }

  return {
    currentRepoContext,
    listRuns,
    viewRun,
    viewRunFailedLog,
    findCurrentBranchRun,
    pollRunUntilDone,
  };
}
