/**
 * Smoke tests for index.ts — extension registration surface.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import ciBrowserExtension from "./index.ts";

// ── Helpers ─────────────────────────────────────────────────────────────────

function fakePi() {
  const tools: Array<{
    name: string;
    description?: string;
    promptSnippet?: string;
    promptGuidelines?: string[];
    parameters?: unknown;
  }> = [];
  const commands = new Map<
    string,
    { description?: string; handler: Function }
  >();

  return {
    tools,
    commands,
    api: {
      exec: async () => ({ stdout: "", stderr: "", code: 0, killed: false }),
      registerTool: (tool: (typeof tools)[number]) => tools.push(tool),
      registerCommand: (
        name: string,
        command: { description?: string; handler: Function },
      ) => {
        commands.set(name, command);
      },
    },
  };
}

// ── Extension registration ──────────────────────────────────────────────────

describe("ci-browser extension", () => {
  it("registers all CI tools and the /ci command", () => {
    const pi = fakePi();

    ciBrowserExtension(pi.api as never);

    assert.deepEqual(pi.tools.map((tool) => tool.name).sort(), [
      "ci_find_current_branch_run",
      "ci_list_runs",
      "ci_view_run",
      "ci_watch_current_branch",
      "ci_watch_run",
    ]);

    for (const tool of pi.tools) {
      assert.equal(typeof tool.description, "string");
      assert.equal(typeof tool.promptSnippet, "string");
      assert.ok((tool.promptGuidelines?.length ?? 0) > 0);
      assert.ok(tool.parameters);
    }

    assert.ok(pi.commands.has("ci"));
    assert.match(pi.commands.get("ci")!.description ?? "", /GitHub Actions/);
  });

  it("reports a clear message when /ci is used without an interactive UI", async () => {
    const pi = fakePi();
    const notifications: Array<{ message: string; level: string }> = [];

    ciBrowserExtension(pi.api as never);

    await pi.commands.get("ci")!.handler("", {
      hasUI: false,
      ui: {
        notify: (message: string, level: string) => {
          notifications.push({ message, level });
        },
      },
    });

    assert.deepEqual(notifications, [
      {
        message:
          "/ci requires interactive mode. Use ci_list_runs, ci_view_run, or ci_watch_run tools instead.",
        level: "warning",
      },
    ]);
  });
});
