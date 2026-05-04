import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { resolve } from "node:path";

const ELIXIR_EXTENSIONS = [".ex", ".exs", ".heex"];

function isPiTsFile(path: string, cwd: string): boolean {
  if (!path.endsWith(".ts")) return false;
  const piDir = resolve(cwd, ".pi");
  return resolve(cwd, path).startsWith(piDir);
}

async function formatElixir(
  pi: ExtensionAPI,
  path: string,
  signal: AbortSignal | undefined,
) {
  await pi.exec("mix", ["format", path], { signal, timeout: 10_000 });
}

async function formatTypeScript(
  pi: ExtensionAPI,
  path: string,
  signal: AbortSignal | undefined,
) {
  await pi.exec("prettier", ["--write", path], { signal, timeout: 10_000 });
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_result", async (event, ctx) => {
    // Only hook into file-modifying tools, and only on success
    if (event.toolName !== "edit" && event.toolName !== "write") return;
    if (event.isError) return;

    // Get the file path from the tool input
    const path = event.input?.path;
    if (typeof path !== "string") return;

    // Determine formatter based on file type
    if (ELIXIR_EXTENSIONS.some((ext) => path.endsWith(ext))) {
      try {
        await formatElixir(pi, path, ctx.signal);
      } catch {
        /* ignore */
      }
    } else if (isPiTsFile(path, ctx.cwd)) {
      try {
        await formatTypeScript(pi, path, ctx.signal);
      } catch {
        /* ignore */
      }
    }
  });
}
