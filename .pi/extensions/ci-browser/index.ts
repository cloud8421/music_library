/**
 * CI Browser — pi extension for browsing GitHub Actions CI runs via `gh` CLI.
 *
 * Tools:
 *   ci_list_runs               — List recent workflow runs
 *   ci_view_run                — View run detail with jobs/steps
 *   ci_find_current_branch_run — Find watchable run for current branch
 *   ci_watch_run               — Poll a run until terminal state
 *   ci_watch_current_branch    — Find and watch current-branch run
 *
 * Command:
 *   /ci  — Interactive TUI browser for CI runs
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import { createCiClient } from "./ci-client.ts";
import * as fmt from "./format.ts";
import type { RunListItem, RunDetail } from "./ci-client.ts";
import type { CiClient } from "./ci-client.ts";

// ── Helpers ─────────────────────────────────────────────────────────────────

type SelectItem = { value: string; label: string; description?: string };

type TuiComponents = {
  BorderedLoader: any;
  DynamicBorder: any;
  Container: any;
  SelectList: any;
  Text: any;
};

function stringEnum<const T extends readonly string[]>(values: T) {
  return Type.Unsafe<T[number]>({ type: "string", enum: [...values] });
}

async function loadTuiComponents(): Promise<TuiComponents> {
  const [codingAgent, tui] = await Promise.all([
    import("@earendil-works/pi-coding-agent"),
    import("@earendil-works/pi-tui"),
  ]);

  return {
    BorderedLoader: codingAgent.BorderedLoader,
    DynamicBorder: codingAgent.DynamicBorder,
    Container: tui.Container,
    SelectList: tui.SelectList,
    Text: tui.Text,
  };
}

function friendlyError(err: unknown): string {
  if (err instanceof Error) return err.message;
  return String(err);
}

// ── Extension ───────────────────────────────────────────────────────────────

export default function ciBrowserExtension(pi: ExtensionAPI) {
  const exec = pi.exec.bind(pi);
  const client = createCiClient(exec);

  // ── Local helpers (capture pi / client) ───────────────────────────────

  function statusLabel(run: RunListItem): string {
    if (run.status === "completed" && run.conclusion) {
      const labels: Record<string, string> = {
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
      return labels[run.conclusion] ?? run.conclusion.toUpperCase();
    }
    const labels: Record<string, string> = {
      queued: "QUEUED",
      in_progress: "RUNNING",
      requested: "QUEUED",
      waiting: "WAITING",
      pending: "PENDING",
      completed: "DONE",
    };
    return labels[run.status] ?? run.status.toUpperCase();
  }

  async function showDetail(text: string, ctx: any, components: TuiComponents) {
    const { Container, DynamicBorder, Text } = components;

    await ctx.ui.custom<null>((tui: any, theme: any, _kb: any, done: any) => {
      const container = new Container();
      container.addChild(
        new DynamicBorder((s: string) => theme.fg("accent", s)),
      );
      for (const line of text.split("\n")) {
        container.addChild(new Text(line, 1, 0));
      }
      container.addChild(new Text("", 1, 0));
      container.addChild(new Text(theme.fg("dim", "esc  back"), 1, 0));
      container.addChild(
        new DynamicBorder((s: string) => theme.fg("accent", s)),
      );
      return {
        render(width: number) {
          return container.render(width);
        },
        invalidate() {
          container.invalidate();
        },
        handleInput(data: string) {
          if (data === "\x1b") done(null);
        },
      };
    });
  }

  async function watchRunInTui(
    runId: number,
    ctx: any,
    components: TuiComponents,
  ) {
    const { Container, DynamicBorder, Text } = components;
    const controller = new AbortController();

    const finalText = await ctx.ui.custom<string | null>(
      (tui: any, theme: any, _kb: any, done: any) => {
        const container = new Container();
        container.addChild(
          new DynamicBorder((s: string) => theme.fg("accent", s)),
        );
        container.addChild(
          new Text(
            theme.fg("accent", theme.bold(`Watching run #${runId}`)),
            1,
            0,
          ),
        );
        container.addChild(
          new Text(
            theme.fg("muted", "Polling every 10s — esc to cancel"),
            1,
            0,
          ),
        );
        container.addChild(new Text("", 1, 0));

        const watchText = new Text("Loading run status...", 1, 0);
        container.addChild(watchText);
        container.addChild(new Text("", 1, 0));
        container.addChild(new Text(theme.fg("dim", "esc  cancel"), 1, 0));
        container.addChild(
          new DynamicBorder((s: string) => theme.fg("accent", s)),
        );

        client
          .pollRunUntilDone(
            runId,
            { intervalMs: 10_000, timeoutMs: 1_800_000 },
            controller.signal,
            (state) => {
              watchText.setText(fmt.formatWatchProgress(state));
              tui.requestRender();
            },
          )
          .then((result) => {
            done(
              fmt.formatWatchResult(result, {
                intervalMs: 10_000,
                timeoutMs: 1_800_000,
              }),
            );
          })
          .catch((err: unknown) => {
            done(`Watch error: ${friendlyError(err)}`);
          });

        return {
          render(width: number) {
            return container.render(width);
          },
          invalidate() {
            container.invalidate();
          },
          handleInput(data: string) {
            if (data === "\x1b") controller.abort();
          },
        };
      },
    );

    if (finalText) {
      await showDetail(finalText, ctx, components);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // Tool: ci_list_runs
  // ════════════════════════════════════════════════════════════════════════

  pi.registerTool({
    name: "ci_list_runs",
    label: "CI List Runs",
    description:
      "List recent GitHub Actions workflow runs using the gh CLI. " +
      "Returns run IDs, workflow names, branches, status/conclusion, titles, and ages.",
    promptSnippet:
      "List recent CI runs with optional branch, status, or workflow filters (limit 1-100, default 20).",
    promptGuidelines: [
      "Use ci_list_runs when asked about recent CI/CD runs, workflow status, or to find a run ID.",
      "After listing, use ci_view_run to inspect a specific run's jobs and steps.",
    ],
    parameters: Type.Object({
      branch: Type.Optional(
        Type.String({ description: "Filter by branch name" }),
      ),
      status: Type.Optional(
        stringEnum([
          "queued",
          "completed",
          "in_progress",
          "requested",
          "waiting",
          "pending",
          "failure",
          "success",
        ] as const),
      ),
      workflow: Type.Optional(
        Type.String({ description: "Filter by workflow name" }),
      ),
      limit: Type.Optional(
        Type.Number({
          description: "Maximum runs to return (1-100, default 20)",
        }),
      ),
    }),
    async execute(_id, params, _signal) {
      const runs = await client.listRuns({
        branch: params.branch as string | undefined,
        status: params.status as string | undefined,
        workflow: params.workflow as string | undefined,
        limit: params.limit as number | undefined,
      });

      if (runs.length === 0) {
        return {
          content: [
            {
              type: "text" as const,
              text: "No runs found matching the given filters.",
            },
          ],
          details: { runs: [] },
        };
      }

      const text = fmt.formatRunListCompact(runs);
      return {
        content: [{ type: "text" as const, text }],
        details: { runs },
      };
    },
  });

  // ════════════════════════════════════════════════════════════════════════
  // Tool: ci_view_run
  // ════════════════════════════════════════════════════════════════════════

  pi.registerTool({
    name: "ci_view_run",
    label: "CI View Run",
    description:
      "View detailed information about a specific GitHub Actions workflow run, " +
      "including jobs, steps, status, timestamps, and optional failed logs.",
    promptSnippet:
      "View a CI run's jobs, steps, status, and optional failed logs by run ID.",
    promptGuidelines: [
      "Use ci_view_run to inspect a specific CI run after obtaining its ID from ci_list_runs.",
      "Set includeFailedLog to true only when investigating a failed run — failed logs can be large.",
    ],
    parameters: Type.Object({
      runId: Type.Number({ description: "The GitHub Actions run database ID" }),
      attempt: Type.Optional(
        Type.Number({ description: "Specific attempt number" }),
      ),
      includeFailedLog: Type.Optional(
        Type.Boolean({
          description:
            "Include failed step logs (default false). Logs are truncated at ~50KB.",
        }),
      ),
    }),
    async execute(_id, params, _signal) {
      const run = await client.viewRun(params.runId as number, {
        attempt: params.attempt as number | undefined,
      });

      let failedLog: string | undefined;
      if (params.includeFailedLog) {
        try {
          const raw = await client.viewRunFailedLog(params.runId as number);
          if (raw.trim()) {
            const tr = fmt.truncateText(raw);
            failedLog =
              tr.content + (tr.truncated ? fmt.formatTruncationNotice(tr) : "");
          }
        } catch {
          failedLog = "(Failed to retrieve failed-step logs)";
        }
      }

      const text = fmt.formatRunDetail(run, failedLog);
      return {
        content: [{ type: "text" as const, text }],
        details: { run },
      };
    },
  });

  // ════════════════════════════════════════════════════════════════════════
  // Tool: ci_find_current_branch_run
  // ════════════════════════════════════════════════════════════════════════

  pi.registerTool({
    name: "ci_find_current_branch_run",
    label: "CI Find Current Branch Run",
    description:
      "Detect the current git branch and find the newest watchable CI run " +
      "(preferring HEAD-commit match, falling back to branch match). " +
      "Returns the run detail or a clear no-active-run result.",
    promptSnippet:
      "Find the watchable CI run for the current git branch (HEAD first, then branch fallback).",
    promptGuidelines: [
      "Use ci_find_current_branch_run to check what CI is running on the current branch.",
      "If it returns a watchable run, use ci_watch_run or ci_watch_current_branch to monitor it.",
    ],
    parameters: Type.Object({}),
    async execute(_id, _params, _signal) {
      const result = await client.findCurrentBranchRun();
      const text = fmt.formatFindResult(result);

      return {
        content: [{ type: "text" as const, text }],
        details: { result },
      };
    },
  });

  // ════════════════════════════════════════════════════════════════════════
  // Tool: ci_watch_run
  // ════════════════════════════════════════════════════════════════════════

  pi.registerTool({
    name: "ci_watch_run",
    label: "CI Watch Run",
    description:
      "Poll a specific GitHub Actions workflow run until it reaches a terminal " +
      "state (completed, cancelled, etc.), a timeout, or the caller cancels. " +
      "Streams progress via onUpdate. Uses gh CLI for polling.",
    promptSnippet:
      "Watch a CI run poll until completion, timeout (default 30m), or cancellation.",
    promptGuidelines: [
      "Use ci_watch_run to monitor a specific CI run to completion.",
      "Reports the final status/conclusion and polling stats. Cancel with signal.",
    ],
    parameters: Type.Object({
      runId: Type.Number({ description: "The GitHub Actions run database ID" }),
      intervalSeconds: Type.Optional(
        Type.Number({
          description: "Polling interval in seconds (5-60, default 10)",
        }),
      ),
      timeoutSeconds: Type.Optional(
        Type.Number({
          description:
            "Watch timeout in seconds (30-3600, default 1800 = 30 min)",
        }),
      ),
    }),
    async execute(_id, params, signal, onUpdate) {
      const intervalSec = (params.intervalSeconds as number | undefined) ?? 10;
      const timeoutSec = (params.timeoutSeconds as number | undefined) ?? 1800;

      const result = await client.pollRunUntilDone(
        params.runId as number,
        { intervalMs: intervalSec * 1000, timeoutMs: timeoutSec * 1000 },
        signal!,
        onUpdate
          ? (state) => {
              onUpdate({
                content: [
                  {
                    type: "text" as const,
                    text: fmt.formatWatchProgress(state),
                  },
                ],
              });
            }
          : undefined,
      );

      const text = fmt.formatWatchResult(result, {
        intervalMs: intervalSec * 1000,
        timeoutMs: timeoutSec * 1000,
      });

      return {
        content: [{ type: "text" as const, text }],
        details: { result },
      };
    },
  });

  // ════════════════════════════════════════════════════════════════════════
  // Tool: ci_watch_current_branch
  // ════════════════════════════════════════════════════════════════════════

  pi.registerTool({
    name: "ci_watch_current_branch",
    label: "CI Watch Current Branch",
    description:
      "Find the current branch's watchable CI run and poll it until completion. " +
      "Returns a no-active-run notice if no watchable run exists.",
    promptSnippet: "Find and watch the current branch CI run to completion.",
    promptGuidelines: [
      "Use ci_watch_current_branch to find and monitor the CI run for the current git branch.",
      "If no active run exists, it returns the latest completed run for context.",
    ],
    parameters: Type.Object({
      intervalSeconds: Type.Optional(
        Type.Number({
          description: "Polling interval in seconds (5-60, default 10)",
        }),
      ),
      timeoutSeconds: Type.Optional(
        Type.Number({
          description:
            "Watch timeout in seconds (30-3600, default 1800 = 30 min)",
        }),
      ),
    }),
    async execute(_id, params, signal, onUpdate) {
      const findResult = await client.findCurrentBranchRun();

      if (findResult.type === "no_active_run") {
        return {
          content: [
            {
              type: "text" as const,
              text: fmt.formatFindResult(findResult),
            },
          ],
          details: { result: findResult },
        };
      }

      const intervalSec = (params.intervalSeconds as number | undefined) ?? 10;
      const timeoutSec = (params.timeoutSeconds as number | undefined) ?? 1800;

      const watchResult = await client.pollRunUntilDone(
        findResult.run!.databaseId,
        { intervalMs: intervalSec * 1000, timeoutMs: timeoutSec * 1000 },
        signal!,
        onUpdate
          ? (state) => {
              onUpdate({
                content: [
                  {
                    type: "text" as const,
                    text: fmt.formatWatchProgress(state),
                  },
                ],
              });
            }
          : undefined,
      );

      const text = fmt.formatWatchResult(watchResult, {
        intervalMs: intervalSec * 1000,
        timeoutMs: timeoutSec * 1000,
      });

      return {
        content: [{ type: "text" as const, text }],
        details: { findResult, watchResult },
      };
    },
  });

  // ════════════════════════════════════════════════════════════════════════
  // Command: /ci
  // ════════════════════════════════════════════════════════════════════════

  pi.registerCommand("ci", {
    description: "Browse and monitor GitHub Actions CI runs",
    handler: async (_args, ctx) => {
      if (!ctx.hasUI) {
        ctx.ui.notify(
          "/ci requires interactive mode. Use ci_list_runs, ci_view_run, or ci_watch_run tools instead.",
          "warning",
        );
        return;
      }

      const components = await loadTuiComponents();
      const { BorderedLoader, Container, DynamicBorder, SelectList, Text } =
        components;

      let runs: RunListItem[] | null = null;
      let errorMsg: string | null = null;

      // ── Fetch with loader ────────────────────────────────────────────

      runs = await ctx.ui.custom<RunListItem[] | null>(
        (tui, theme, _kb, done) => {
          const loader = new BorderedLoader(
            tui,
            theme,
            "Loading CI runs via gh CLI...",
          );
          let settled = false;
          loader.onAbort = () => {
            if (!settled) {
              settled = true;
              done(null);
            }
          };
          client
            .listRuns({ limit: 20 })
            .then((r) => {
              if (!settled) {
                settled = true;
                done(r);
              }
            })
            .catch((err: unknown) => {
              if (!settled) {
                settled = true;
                errorMsg = friendlyError(err);
                done(null);
              }
            });
          return loader;
        },
      );

      if (errorMsg) {
        ctx.ui.notify(errorMsg, "error");
        return;
      }
      if (!runs) {
        ctx.ui.notify("Cancelled", "info");
        return;
      }
      if (runs.length === 0) {
        ctx.ui.notify("No CI runs found in this repository.", "info");
        return;
      }

      let currentRuns = runs;

      // ── Main interaction loop ─────────────────────────────────────────

      while (true) {
        const items: SelectItem[] = currentRuns.map((r) => ({
          value: String(r.databaseId),
          label: `${statusLabel(r).padEnd(10)} ${r.workflowName || r.name}`,
          description: `${r.headBranch}@${r.headSha.slice(0, 7)}  ${fmt.relativeTime(r.createdAt)}  ${r.displayTitle.slice(0, 50)}`,
        }));

        type Action =
          | { kind: "select"; runId: number }
          | { kind: "refresh" }
          | { kind: "watchBranch" }
          | { kind: "quit" };

        const choice = await ctx.ui.custom<Action | null>(
          (tui, theme, _kb, done) => {
            const container = new Container();
            container.addChild(
              new DynamicBorder((s: string) => theme.fg("accent", s)),
            );
            container.addChild(
              new Text(
                theme.fg("accent", theme.bold("GitHub Actions CI Runs")),
                1,
                0,
              ),
            );
            container.addChild(
              new Text(theme.fg("muted", `${currentRuns.length} run(s)`), 1, 0),
            );
            container.addChild(new Text("", 1, 0));

            const selectList = new SelectList(
              items,
              Math.min(items.length, 20),
              {
                selectedPrefix: (t: string) => theme.fg("accent", t),
                selectedText: (t: string) => theme.fg("accent", t),
                description: (t: string) => theme.fg("muted", t),
                scrollInfo: (t: string) => theme.fg("dim", t),
                noMatch: (t: string) => theme.fg("warning", t),
              },
            );
            selectList.onSelect = (item) =>
              done({ kind: "select", runId: Number(item.value) });
            selectList.onCancel = () => done({ kind: "quit" });
            container.addChild(selectList);

            container.addChild(new Text("", 1, 0));
            container.addChild(
              new Text(
                theme.fg(
                  "dim",
                  "↑↓ navigate  ·  enter view  ·  r refresh  ·  w watch branch  ·  esc quit",
                ),
                1,
                0,
              ),
            );
            container.addChild(
              new DynamicBorder((s: string) => theme.fg("accent", s)),
            );

            return {
              render(width: number) {
                return container.render(width);
              },
              invalidate() {
                container.invalidate();
              },
              handleInput(data: string) {
                if (data === "r" || data === "R") done({ kind: "refresh" });
                else if (data === "w" || data === "W")
                  done({ kind: "watchBranch" });
                else {
                  selectList.handleInput(data);
                  tui.requestRender();
                }
              },
            };
          },
        );

        if (!choice) continue;

        switch (choice.kind) {
          case "quit":
            return;

          case "refresh": {
            const fresh = await ctx.ui.custom<RunListItem[] | null>(
              (tui, theme, _kb, done) => {
                const loader = new BorderedLoader(tui, theme, "Refreshing...");
                let settled = false;
                loader.onAbort = () => {
                  if (!settled) {
                    settled = true;
                    done(null);
                  }
                };
                client
                  .listRuns({ limit: 20 })
                  .then((r) => {
                    if (!settled) {
                      settled = true;
                      done(r);
                    }
                  })
                  .catch(() => {
                    if (!settled) {
                      settled = true;
                      done(null);
                    }
                  });
                return loader;
              },
            );
            if (fresh) currentRuns = fresh;
            break;
          }

          case "watchBranch": {
            let findErr: string | null = null;
            let findResult = await ctx.ui.custom<{
              type: string;
              run: RunDetail | null;
              text: string;
            } | null>((tui, theme, _kb, done) => {
              const loader = new BorderedLoader(
                tui,
                theme,
                "Finding current branch run...",
              );
              let settled = false;
              loader.onAbort = () => {
                if (!settled) {
                  settled = true;
                  done(null);
                }
              };
              client
                .findCurrentBranchRun()
                .then((r) => {
                  if (!settled) {
                    settled = true;
                    done({
                      type: r.type,
                      run: r.run,
                      text: fmt.formatFindResult(r),
                    });
                  }
                })
                .catch((err: unknown) => {
                  if (!settled) {
                    settled = true;
                    findErr = friendlyError(err);
                    done(null);
                  }
                });
              return loader;
            });

            if (findErr) {
              ctx.ui.notify(findErr, "error");
              break;
            }
            if (!findResult) break;

            if (findResult.type === "no_active_run") {
              await showDetail(findResult.text, ctx, components);
              break;
            }
            await watchRunInTui(findResult.run!.databaseId, ctx, components);
            break;
          }

          case "select": {
            const runId = choice.runId;
            let viewErr: string | null = null;
            let runDetail = await ctx.ui.custom<RunDetail | null>(
              (tui, theme, _kb, done) => {
                const loader = new BorderedLoader(
                  tui,
                  theme,
                  `Loading run #${runId}...`,
                );
                let settled = false;
                loader.onAbort = () => {
                  if (!settled) {
                    settled = true;
                    done(null);
                  }
                };
                client
                  .viewRun(runId)
                  .then((r) => {
                    if (!settled) {
                      settled = true;
                      done(r);
                    }
                  })
                  .catch((err: unknown) => {
                    if (!settled) {
                      settled = true;
                      viewErr = friendlyError(err);
                      done(null);
                    }
                  });
                return loader;
              },
            );

            if (viewErr) {
              ctx.ui.notify(viewErr, "error");
              break;
            }
            if (!runDetail) break;

            // Detail view loop
            let run = runDetail;
            let failedLog: string | undefined;

            while (true) {
              type DetailAction =
                "back" | "refresh" | "failedLog" | "watch" | "copy";
              const action = await ctx.ui.custom<DetailAction | null>(
                (tui, theme, _kb, done) => {
                  const text = fmt.formatRunDetail(run, failedLog);
                  const container = new Container();
                  container.addChild(
                    new DynamicBorder((s: string) => theme.fg("accent", s)),
                  );
                  for (const line of text.split("\n")) {
                    container.addChild(new Text(line, 1, 0));
                  }
                  container.addChild(new Text("", 1, 0));
                  container.addChild(
                    new Text(
                      theme.fg(
                        "dim",
                        "esc back  ·  r refresh  ·  l failed log  ·  w watch  ·  c copy URL",
                      ),
                      1,
                      0,
                    ),
                  );
                  container.addChild(
                    new DynamicBorder((s: string) => theme.fg("accent", s)),
                  );
                  return {
                    render(width: number) {
                      return container.render(width);
                    },
                    invalidate() {
                      container.invalidate();
                    },
                    handleInput(data: string) {
                      if (data === "\x1b") done("back");
                      else if (data === "r" || data === "R") done("refresh");
                      else if (data === "l" || data === "L") done("failedLog");
                      else if (data === "w" || data === "W") done("watch");
                      else if (data === "c" || data === "C") done("copy");
                    },
                  };
                },
              );

              if (action === "back" || !action) break;

              switch (action) {
                case "refresh": {
                  const fresh = await ctx.ui.custom<RunDetail | null>(
                    (tui, theme, _kb, done) => {
                      const loader = new BorderedLoader(
                        tui,
                        theme,
                        "Refreshing...",
                      );
                      let settled = false;
                      loader.onAbort = () => {
                        if (!settled) {
                          settled = true;
                          done(null);
                        }
                      };
                      client
                        .viewRun(run.databaseId)
                        .then((r) => {
                          if (!settled) {
                            settled = true;
                            done(r);
                          }
                        })
                        .catch(() => {
                          if (!settled) {
                            settled = true;
                            done(null);
                          }
                        });
                      return loader;
                    },
                  );
                  if (fresh) run = fresh;
                  break;
                }
                case "failedLog": {
                  const raw = await ctx.ui.custom<string | null>(
                    (tui, theme, _kb, done) => {
                      const loader = new BorderedLoader(
                        tui,
                        theme,
                        "Fetching failed logs...",
                      );
                      let settled = false;
                      loader.onAbort = () => {
                        if (!settled) {
                          settled = true;
                          done(null);
                        }
                      };
                      client
                        .viewRunFailedLog(run.databaseId)
                        .then((log) => {
                          if (!settled) {
                            settled = true;
                            if (log.trim()) {
                              const tr = fmt.truncateText(log);
                              done(
                                tr.content +
                                  (tr.truncated
                                    ? fmt.formatTruncationNotice(tr)
                                    : ""),
                              );
                            } else {
                              done("(No failed steps or log unavailable)");
                            }
                          }
                        })
                        .catch(() => {
                          if (!settled) {
                            settled = true;
                            done("(Failed to retrieve logs)");
                          }
                        });
                      return loader;
                    },
                  );
                  if (raw) failedLog = raw;
                  break;
                }
                case "watch": {
                  await watchRunInTui(run.databaseId, ctx, components);
                  try {
                    run = await client.viewRun(run.databaseId);
                  } catch {
                    /* keep old */
                  }
                  break;
                }
                case "copy": {
                  ctx.ui.notify(`Run URL: ${run.url}`, "info");
                  break;
                }
              }
            }
            break;
          }
        }
      }
    },
  });
}
