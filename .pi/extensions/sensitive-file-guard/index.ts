import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";
import { readFileSync } from "node:fs";
import { normalize, resolve } from "node:path";
import { extractCommandNames } from "./ast.ts";

interface Config {
  blocked_paths: string[];
  blocked_commands: string[];
}

function loadConfig(cwd: string): Config {
  const raw = readFileSync(resolve(cwd, ".pi/sensitive-paths.json"), "utf-8");
  return JSON.parse(raw) as Config;
}

/** Convert a glob-like pattern to a case-insensitive regex. */
function patternToRegex(pattern: string): RegExp {
  let escaped = pattern
    .replace(/[.+^${}()|[\]\\]/g, "\\$&") // Escape regex specials except *
    .replace(/\*/g, ".*"); // * → .*
  return new RegExp(escaped, "i");
}

export default function (pi: ExtensionAPI) {
  let config: Config;
  try {
    config = loadConfig(process.cwd());
  } catch {
    return; // Config missing or invalid — fail open
  }

  const pathRegexes = config.blocked_paths.map(patternToRegex);
  // Build a Set of lowercased blocked command names for exact matching.
  // Also build regexes for regex fallback when parsing fails.
  const blockedCommands = new Set(
    config.blocked_commands.map((c) => c.toLowerCase()),
  );
  const commandRegexes = config.blocked_commands.map((r) => new RegExp(r, "i"));

  // Proactively tell the agent which paths are off-limits so it doesn't try in the first place
  pi.on("before_agent_start", async (event, _ctx) => {
    if (config.blocked_paths.length === 0) return;
    const pathList = config.blocked_paths.map((p) => `  - \`${p}\``).join("\n");
    return {
      systemPrompt:
        event.systemPrompt +
        `\n\n## Sensitive File Guard\nThese path patterns are protected and all tool access is permanently blocked:\n${pathList}\n\nIf a tool call is blocked, DO NOT retry with alternate tools (bash, find, ls, grep, etc.). Instead, tell the user: "That path is protected by sensitive-file-guard."`,
    };
  });

  pi.on("tool_call", (event, ctx) => {
    // --- Path-based tools ---
    if (
      isToolCallEventType("read", event) ||
      isToolCallEventType("grep", event) ||
      isToolCallEventType("write", event) ||
      isToolCallEventType("edit", event) ||
      isToolCallEventType("find", event) ||
      isToolCallEventType("ls", event)
    ) {
      const path = event.input.path;
      if (typeof path !== "string") return;

      const resolved = normalize(resolve(ctx.cwd, path));
      const match = pathRegexes.find((r) => r.test(resolved));
      if (match) {
        const reason =
          `🚫 ACCESS DENIED by sensitive-file-guard: paths matching "${match}" are permanently protected. ` +
          `DO NOT retry with other tools (bash, find, ls, grep, etc.). ` +
          `Tell the user the file is protected and STOP.`;
        if (ctx.hasUI)
          ctx.ui.notify(`Blocked sensitive path: ${path}`, "warning");
        return { block: true, reason };
      }
      return;
    }

    // --- Bash tool ---
    if (isToolCallEventType("bash", event)) {
      const command = event.input.command;
      if (typeof command !== "string") return;

      // Check for blocked path fragments in the command text
      const pathHit = config.blocked_paths.find((p) => {
        // Rough substring match: does the pattern text (with glob stripped)
        // appear in the command?
        const literal = p.replace(/[*?]/g, "");
        return (
          literal.length > 0 &&
          command.toLowerCase().includes(literal.toLowerCase())
        );
      });

      if (pathHit) {
        const reason =
          `🚫 ACCESS DENIED by sensitive-file-guard: commands targeting "${pathHit}" are permanently blocked. ` +
          `DO NOT retry with alternative commands. Tell the user the path is protected and STOP.`;
        if (ctx.hasUI)
          ctx.ui.notify(
            `Blocked sensitive path in bash: ${pathHit}`,
            "warning",
          );
        return { block: true, reason };
      }

      // --- Parse command structurally to detect blocked commands ---
      const parsedNames = extractCommandNames(command);

      // Use parsed names if we got any (or if the command parsed to empty
      // commands, which means it's a comment or similar non-executable text).
      // Fall back to regex matching if parsing returned an empty set for a
      // non-empty command — this handles parse failures gracefully.
      if (parsedNames.size > 0 || command.trim().length === 0) {
        const cmdHit = [...parsedNames].find((name) =>
          blockedCommands.has(name),
        );
        if (cmdHit) {
          const reason =
            `🚫 ACCESS DENIED by sensitive-file-guard: this command matches a blocked pattern. ` +
            `DO NOT retry. Tell the user the command is blocked and STOP.`;
          if (ctx.hasUI) ctx.ui.notify(`Blocked sensitive command`, "warning");
          return { block: true, reason };
        }
      } else {
        // Fallback: parsing returned nothing for a non-empty command.
        // Use regex-based matching as a conservative safety net.
        const cmdHit = commandRegexes.find((r) => r.test(command));
        if (cmdHit) {
          const reason =
            `🚫 ACCESS DENIED by sensitive-file-guard: this command matches a blocked pattern. ` +
            `DO NOT retry. Tell the user the command is blocked and STOP.`;
          if (ctx.hasUI) ctx.ui.notify(`Blocked sensitive command`, "warning");
          return { block: true, reason };
        }
      }
    }
  });
}
