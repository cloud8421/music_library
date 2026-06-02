/**
 * Tests for ci-client.ts — structured gh/git helper layer.
 *
 * All tests use fake exec functions to simulate CLI output without requiring
 * gh, git, network access, or GitHub authentication.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  createCiClient,
  GhNotFoundError,
  GhAuthError,
  NotAGitRepoError,
  InvalidRunIdError,
  JsonParseError,
  GhCommandError,
  type ExecFn,
  type RunListItem,
  type RunDetail,
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
    headSha: "abc123def456",
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

// ── Fake exec helpers ───────────────────────────────────────────────────────

type FakeResult = string | { stdout?: string; stderr?: string; code?: number };
/** Array values are consumed FIFO per prefix-matched key. Scalars repeat. */
type FakeResultMap = Record<string, FakeResult | FakeResult[]>;

function toOutput(match: FakeResult | undefined): {
  stdout: string;
  stderr: string;
  code: number;
  killed: boolean;
} {
  if (typeof match === "string") {
    return { stdout: match, stderr: "", code: 0, killed: false };
  }
  if (match) {
    return {
      stdout: match.stdout ?? "",
      stderr: match.stderr ?? "",
      code: match.code ?? 0,
      killed: false,
    };
  }
  return { stdout: "", stderr: "unknown command", code: 127, killed: false };
}

/**
 * fakeExec — scalar values repeat forever; array values are consumed FIFO
 * (matched by exact key, then by prefix).
 */
function fakeExec(map: FakeResultMap): ExecFn {
  // Separate arrays (consumable) from scalars (repeatable)
  const queues = new Map<string, FakeResult[]>();
  const scalars = new Map<string, FakeResult>();
  for (const [k, v] of Object.entries(map)) {
    if (Array.isArray(v)) {
      queues.set(k, [...v]);
    } else {
      scalars.set(k, v);
    }
  }

  return async (command, args) => {
    const key = [command, ...args].join(" ");
    // Exact match first
    if (queues.has(key)) {
      return toOutput(queues.get(key)!.shift());
    }
    if (scalars.has(key)) {
      return toOutput(scalars.get(key)!);
    }
    // Prefix match on queues
    for (const [qk, qv] of queues) {
      if (key.startsWith(qk)) return toOutput(qv.shift());
    }
    // Prefix match on scalars
    for (const [sk, sv] of scalars) {
      if (key.startsWith(sk)) return toOutput(sv);
    }
    return toOutput(undefined);
  };
}

// ── currentRepoContext ──────────────────────────────────────────────────────

describe("currentRepoContext", () => {
  it("returns branch and sha when in a repo", async () => {
    const exec = fakeExec({
      "git rev-parse --is-inside-work-tree": "true\n",
      "git branch --show-current": "main\n",
      "git rev-parse HEAD": "abc123def456789\n",
    });
    const client = createCiClient(exec);
    const ctx = await client.currentRepoContext();
    assert.equal(ctx.branch, "main");
    assert.equal(ctx.headSha, "abc123def456789");
  });

  it("returns (detached HEAD) for detached HEAD state", async () => {
    const exec = fakeExec({
      "git rev-parse --is-inside-work-tree": "true\n",
      "git branch --show-current": "\n",
      "git rev-parse HEAD": "abc123\n",
    });
    const client = createCiClient(exec);
    const ctx = await client.currentRepoContext();
    assert.equal(ctx.branch, "(detached HEAD)");
    assert.equal(ctx.headSha, "abc123");
  });

  it("throws NotAGitRepoError when not in a git repo", async () => {
    const exec: ExecFn = async (cmd, args) => {
      if (cmd === "git" && args[0] === "rev-parse") {
        return {
          stdout: "",
          stderr: "fatal: not a git repository",
          code: 128,
          killed: false,
        };
      }
      return { stdout: "", stderr: "", code: 0, killed: false };
    };
    const client = createCiClient(exec);
    await assert.rejects(() => client.currentRepoContext(), NotAGitRepoError);
  });
});

// ── listRuns ────────────────────────────────────────────────────────────────

describe("listRuns", () => {
  const runs: RunListItem[] = [fakeRun(), fakeRun({ databaseId: 12346 })];

  it("parses valid gh run list JSON", async () => {
    const exec = fakeExec({ "gh run list": JSON.stringify(runs) });
    const client = createCiClient(exec);
    const result = await client.listRuns();
    assert.equal(result.length, 2);
    assert.equal(result[0].databaseId, 12345);
  });

  it("returns empty array for no runs", async () => {
    const exec = fakeExec({ "gh run list": "[]" });
    const client = createCiClient(exec);
    const result = await client.listRuns();
    assert.equal(result.length, 0);
  });

  it("throws JsonParseError for invalid JSON", async () => {
    const exec = fakeExec({ "gh run list": "not json" });
    const client = createCiClient(exec);
    await assert.rejects(() => client.listRuns(), JsonParseError);
  });

  it("throws GhNotFoundError when gh is missing", async () => {
    const exec = fakeExec({
      "gh run list": { stdout: "", stderr: "gh: command not found", code: 127 },
    });
    const client = createCiClient(exec);
    await assert.rejects(() => client.listRuns(), GhNotFoundError);
  });

  it("throws GhAuthError when unauthenticated", async () => {
    const exec = fakeExec({
      "gh run list": { stdout: "", stderr: "not authenticated", code: 1 },
    });
    const client = createCiClient(exec);
    await assert.rejects(() => client.listRuns(), GhAuthError);
  });

  it("passes branch, status, limit, commit options", async () => {
    let capturedArgs: string[] = [];
    const exec: ExecFn = async (_cmd, args) => {
      capturedArgs = [...args];
      return { stdout: "[]", stderr: "", code: 0, killed: false };
    };
    const client = createCiClient(exec);
    await client.listRuns({
      branch: "feat/x",
      status: "completed",
      limit: 10,
      commit: "abc",
    });
    assert.ok(capturedArgs.includes("--branch"));
    assert.ok(capturedArgs.includes("feat/x"));
    assert.ok(capturedArgs.includes("--status"));
    assert.ok(capturedArgs.includes("completed"));
    assert.ok(capturedArgs.includes("--limit"));
    assert.ok(capturedArgs.includes("10"));
    assert.ok(capturedArgs.includes("--commit"));
    assert.ok(capturedArgs.includes("abc"));
  });

  it("clamps limit to [1, 100]", async () => {
    let capturedArgs: string[] = [];
    const exec: ExecFn = async (_cmd, args) => {
      capturedArgs = [...args];
      return { stdout: "[]", stderr: "", code: 0, killed: false };
    };
    const client = createCiClient(exec);
    await client.listRuns({ limit: 0 });
    assert.equal(capturedArgs[capturedArgs.indexOf("--limit") + 1], "1");
    capturedArgs = [];
    await client.listRuns({ limit: 500 });
    assert.equal(capturedArgs[capturedArgs.indexOf("--limit") + 1], "100");
  });
});

// ── viewRun ─────────────────────────────────────────────────────────────────

describe("viewRun", () => {
  const detail = fakeDetail();

  it("parses valid gh run view JSON", async () => {
    const exec = fakeExec({ "gh run view": JSON.stringify(detail) });
    const client = createCiClient(exec);
    const result = await client.viewRun(12345);
    assert.equal(result.databaseId, 12345);
    assert.equal(result.jobs.length, 1);
    assert.equal(result.jobs[0].steps.length, 2);
  });

  it("throws InvalidRunIdError for unknown run", async () => {
    const exec = fakeExec({
      "gh run view": { stdout: "", stderr: "run not found", code: 1 },
    });
    const client = createCiClient(exec);
    await assert.rejects(() => client.viewRun(99999), InvalidRunIdError);
  });

  it("passes attempt flag when specified", async () => {
    let capturedArgs: string[] = [];
    const exec: ExecFn = async (_cmd, args) => {
      capturedArgs = [...args];
      return {
        stdout: JSON.stringify(detail),
        stderr: "",
        code: 0,
        killed: false,
      };
    };
    const client = createCiClient(exec);
    await client.viewRun(12345, { attempt: 2 });
    assert.ok(capturedArgs.includes("--attempt"));
    assert.ok(capturedArgs.includes("2"));
  });
});

// ── viewRunFailedLog ────────────────────────────────────────────────────────

describe("viewRunFailedLog", () => {
  it("returns log text on success", async () => {
    const exec = fakeExec({ "gh run view": "Error: boom\n    at step 3\n" });
    const client = createCiClient(exec);
    const result = await client.viewRunFailedLog(12345);
    assert.equal(result, "Error: boom\n    at step 3\n");
  });

  it("returns empty string when no failed steps", async () => {
    const exec = fakeExec({
      "gh run view": { stdout: "", stderr: "no failed steps", code: 0 },
    });
    const client = createCiClient(exec);
    const result = await client.viewRunFailedLog(12345);
    assert.equal(result, "");
  });

  it("throws InvalidRunIdError for unknown run", async () => {
    const exec = fakeExec({
      "gh run view": { stdout: "", stderr: "could not find any runs", code: 1 },
    });
    const client = createCiClient(exec);
    await assert.rejects(
      () => client.viewRunFailedLog(99999),
      InvalidRunIdError,
    );
  });
});

// ── findCurrentBranchRun ────────────────────────────────────────────────────

describe("findCurrentBranchRun", () => {
  it("selects watchable HEAD-commit run", async () => {
    const exec = fakeExec({
      "git rev-parse --is-inside-work-tree": "true\n",
      "git branch --show-current": "main\n",
      "git rev-parse HEAD": "abc123\n",
      "gh run list": JSON.stringify([
        fakeRun({
          databaseId: 111,
          headSha: "abc123",
          status: "in_progress",
          conclusion: null,
        }),
        fakeRun({ databaseId: 110, status: "completed" }),
      ]),
      "gh run view": JSON.stringify(
        fakeDetail({
          databaseId: 111,
          status: "in_progress",
          conclusion: null,
        }),
      ),
    });
    const client = createCiClient(exec);
    const result = await client.findCurrentBranchRun();
    assert.equal(result.type, "watchable");
    assert.equal(result.run!.databaseId, 111);
    assert.equal(result.headShaDiffers, false);
    assert.equal(result.latestCompleted!.databaseId, 110);
  });

  it("falls back to branch run when HEAD has no watchable", async () => {
    const exec = fakeExec({
      "git rev-parse --is-inside-work-tree": "true\n",
      "git branch --show-current": "main\n",
      "git rev-parse HEAD": "abc123\n",
      "gh run list": [
        JSON.stringify([
          fakeRun({ databaseId: 110, headSha: "abc123", status: "completed" }),
        ]),
        JSON.stringify([
          fakeRun({
            databaseId: 111,
            headSha: "def456",
            status: "in_progress",
            conclusion: null,
          }),
          fakeRun({ databaseId: 110, status: "completed" }),
        ]),
      ],
      "gh run view": JSON.stringify(
        fakeDetail({
          databaseId: 111,
          status: "in_progress",
          conclusion: null,
        }),
      ),
    });
    const client = createCiClient(exec);
    const result = await client.findCurrentBranchRun();
    assert.equal(result.type, "branch_fallback");
    assert.equal(result.run!.databaseId, 111);
    assert.equal(result.headShaDiffers, true);
  });

  it("returns no_active_run when no watchable runs exist", async () => {
    const completed = fakeRun({ databaseId: 110, status: "completed" });
    const exec = fakeExec({
      "git rev-parse --is-inside-work-tree": "true\n",
      "git branch --show-current": "main\n",
      "git rev-parse HEAD": "abc123\n",
      // findCurrentBranchRun calls listRuns up to 3 times in the no-active-run path
      "gh run list": [
        JSON.stringify([completed]),
        JSON.stringify([completed]),
        JSON.stringify([completed]),
      ],
    });
    const client = createCiClient(exec);
    const result = await client.findCurrentBranchRun();
    assert.equal(result.type, "no_active_run");
    assert.equal(result.run, null);
    assert.equal(result.latestCompleted!.databaseId, 110);
  });

  it("returns no_active_run without latestCompleted when no runs at all", async () => {
    const exec = fakeExec({
      "git rev-parse --is-inside-work-tree": "true\n",
      "git branch --show-current": "main\n",
      "git rev-parse HEAD": "abc123\n",
      "gh run list": ["[]", "[]", "[]"],
    });
    const client = createCiClient(exec);
    const result = await client.findCurrentBranchRun();
    assert.equal(result.type, "no_active_run");
    assert.equal(result.run, null);
    assert.equal(result.latestCompleted, null);
  });

  it("handles detached HEAD gracefully", async () => {
    const exec = fakeExec({
      "git rev-parse --is-inside-work-tree": "true\n",
      "git branch --show-current": "\n",
      "git rev-parse HEAD": "abc123\n",
    });
    const client = createCiClient(exec);
    const result = await client.findCurrentBranchRun();
    assert.equal(result.type, "no_active_run");
    assert.equal(result.run, null);
    assert.equal(result.latestCompleted, null);
  });
});

// ── pollRunUntilDone ────────────────────────────────────────────────────────

describe("pollRunUntilDone", () => {
  it("returns immediately when run is already terminal", async () => {
    const exec = fakeExec({
      "gh run view": JSON.stringify(
        fakeDetail({ status: "completed", conclusion: "success" }),
      ),
    });
    const client = createCiClient(exec);
    const ctl = new AbortController();
    const updates: unknown[] = [];
    const result = await client.pollRunUntilDone(
      12345,
      { intervalMs: 100, timeoutMs: 5000 },
      ctl.signal,
      (s) => updates.push(s),
    );
    assert.equal(result.cancelled, false);
    assert.equal(result.timedOut, false);
    assert.equal(result.pollCount, 1);
    assert.equal(updates.length, 1);
  });

  it("polls until terminal state", async () => {
    let calls = 0;
    const exec: ExecFn = async () => {
      calls++;
      return {
        stdout: JSON.stringify(
          calls === 1
            ? fakeDetail({ status: "in_progress", conclusion: null })
            : fakeDetail({ status: "completed", conclusion: "success" }),
        ),
        stderr: "",
        code: 0,
        killed: false,
      };
    };
    const client = createCiClient(exec);
    const ctl = new AbortController();
    const updates: unknown[] = [];
    const result = await client.pollRunUntilDone(
      12345,
      {
        intervalMs: 50,
        timeoutMs: 30_000,
        sleep: async () => {},
      },
      ctl.signal,
      (s) => updates.push(s),
    );
    assert.equal(result.cancelled, false);
    assert.equal(result.timedOut, false);
    assert.equal(result.pollCount, 2);
    assert.equal(updates.length, 2);
  });

  it("respects cancellation via AbortSignal", async () => {
    const exec = fakeExec({
      "gh run view": JSON.stringify(
        fakeDetail({ status: "in_progress", conclusion: null }),
      ),
    });
    const client = createCiClient(exec);
    const ctl = new AbortController();
    setTimeout(() => ctl.abort(), 50);
    const result = await client.pollRunUntilDone(
      12345,
      { intervalMs: 200, timeoutMs: 30_000 },
      ctl.signal,
    );
    assert.equal(result.cancelled, true);
    assert.equal(result.timedOut, false);
  });

  it("respects timeout without making an extra poll after the timeout", async () => {
    let calls = 0;
    let now = 0;
    const exec: ExecFn = async () => {
      calls++;
      return {
        stdout: JSON.stringify(
          fakeDetail({ status: "in_progress", conclusion: null }),
        ),
        stderr: "",
        code: 0,
        killed: false,
      };
    };
    const client = createCiClient(exec);
    const ctl = new AbortController();

    const result = await client.pollRunUntilDone(
      12345,
      {
        intervalMs: 60_000,
        timeoutMs: 30_000,
        now: () => now,
        sleep: async (ms) => {
          now += ms;
        },
      },
      ctl.signal,
    );

    assert.equal(result.cancelled, false);
    assert.equal(result.timedOut, true);
    assert.equal(result.pollCount, 1);
    assert.equal(calls, 1);
  });

  it("clamps interval and timeout", async () => {
    const exec = fakeExec({
      "gh run view": JSON.stringify(
        fakeDetail({ status: "completed", conclusion: "success" }),
      ),
    });
    const client = createCiClient(exec);
    const ctl = new AbortController();
    const result = await client.pollRunUntilDone(
      12345,
      { intervalMs: 100, timeoutMs: 100 },
      ctl.signal,
    );
    // Run is already terminal, so returns immediately regardless of clamps
    assert.equal(result.pollCount, 1);
    assert.equal(result.timedOut, false);
    assert.equal(result.cancelled, false);
  });
});

// ── Error edge cases ────────────────────────────────────────────────────────

describe("error handling", () => {
  it("throws GhCommandError for unknown non-zero exit", async () => {
    const exec = fakeExec({
      "gh run list": { stdout: "", stderr: "something went wrong", code: 2 },
    });
    const client = createCiClient(exec);
    await assert.rejects(() => client.listRuns(), GhCommandError);
  });

  it("throws JsonParseError for malformed JSON in view", async () => {
    const exec = fakeExec({ "gh run view": "{ broken json" });
    const client = createCiClient(exec);
    await assert.rejects(() => client.viewRun(12345), JsonParseError);
  });
});
