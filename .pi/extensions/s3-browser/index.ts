/**
 * S3 Backup Browser
 *
 * Lists backup files in the Litestream S3 bucket as a scrollable TUI.
 *
 * Credentials are read from the same environment variables used by
 * scripts/prod/litestream-backup:
 *   LITESTREAM_ACCESS_KEY_ID
 *   LITESTREAM_SECRET_ACCESS_KEY
 *
 * Usage:
 *   /backups
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { BorderedLoader, DynamicBorder } from "@mariozechner/pi-coding-agent";
import {
  Container,
  type SelectItem,
  SelectList,
  Text,
} from "@mariozechner/pi-tui";
import { listAllObjects, type S3ClientConfig } from "./s3-client";

// Re-export for consumers
export {
  AuthError,
  NetworkError,
  AbortError,
  type S3Object,
} from "./s3-client";

// ── S3 configuration (mirrors scripts/prod/litestream-backup) ────────────────
const S3_ENDPOINT = "https://nbg1.your-objectstorage.com";
const S3_BUCKET = "ffmusiclibrary";
const S3_PREFIX = "prod/";
const S3_REGION = "nbg1";

// ── Helpers ─────────────────────────────────────────────────────────────────

function humanSize(bytes: number): string {
  if (bytes === 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.min(
    Math.floor(Math.log(bytes) / Math.log(1024)),
    units.length - 1,
  );
  return `${(bytes / 1024 ** i).toFixed(1)} ${units[i]}`;
}

function formatDate(d: Date): string {
  // YYYY-MM-DD HH:MM
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/**
 * Strip the known prefix from an S3 key for cleaner display.
 */
function displayKey(key: string): string {
  if (key.startsWith(S3_PREFIX)) return key.slice(S3_PREFIX.length);
  return key;
}

// ── Extension ───────────────────────────────────────────────────────────────

export default function s3BrowserExtension(pi: ExtensionAPI) {
  pi.registerCommand("backups", {
    description: "List backup files in the S3 bucket",
    handler: async (_args, ctx) => {
      // ── Validate credentials ────────────────────────────────────────────

      const accessKeyId = process.env.LITESTREAM_ACCESS_KEY_ID;
      const secretAccessKey = process.env.LITESTREAM_SECRET_ACCESS_KEY;

      if (!accessKeyId || !secretAccessKey) {
        ctx.ui.notify(
          "Missing LITESTREAM_ACCESS_KEY_ID or LITESTREAM_SECRET_ACCESS_KEY env vars",
          "error",
        );
        return;
      }

      // ── Fetch objects with loader UI ────────────────────────────────────

      const objects = await ctx.ui.custom<S3Object[] | null>(
        (tui, theme, _kb, done) => {
          const loader = new BorderedLoader(
            tui,
            theme,
            "Fetching backup list from S3...",
          );

          const doFetch = async (): Promise<S3Object[]> => {
            const config: S3ClientConfig = {
              endpoint: new URL(S3_ENDPOINT).host,
              region: S3_REGION,
              bucket: S3_BUCKET,
              accessKeyId,
              secretAccessKey,
            };
            return listAllObjects(config, { prefix: S3_PREFIX }, loader.signal);
          };

          let settled = false;
          const finish = (result: S3Object[] | null) => {
            if (!settled) {
              settled = true;
              done(result);
            }
          };
          loader.onAbort = () => finish(null);

          doFetch()
            .then(finish)
            .catch((err: unknown) => {
              if (err instanceof AuthError) {
                ctx.ui.notify(
                  "Authentication failed — check LITESTREAM_ACCESS_KEY_ID / LITESTREAM_SECRET_ACCESS_KEY",
                  "error",
                );
              } else if (err instanceof NetworkError) {
                ctx.ui.notify(
                  "Could not reach S3 endpoint — check network",
                  "error",
                );
              } else if (err instanceof AbortError) {
                // User cancelled — clean cancellation, no notification needed
              } else {
                console.error("[s3-browser] Fetch failed:", err);
              }
              finish(null);
            });

          return loader;
        },
      );

      if (objects === null) {
        ctx.ui.notify(
          "Cancelled or fetch failed — check logs for details",
          "info",
        );
        return;
      }

      if (objects.length === 0) {
        ctx.ui.notify("No backup files found in bucket", "info");
        return;
      }

      // ── Build the file list UI ──────────────────────────────────────────

      const totalSize = objects.reduce((sum, o) => sum + o.size, 0);

      const items: SelectItem[] = objects.map((obj) => ({
        value: obj.key,
        label: displayKey(obj.key),
        description: `${humanSize(obj.size)}  │  ${formatDate(obj.lastModified)}`,
      }));

      // Summary header line
      const summary = `${objects.length} files  ·  ${humanSize(totalSize)} total`;

      const selectedKey = await ctx.ui.custom<string | null>(
        (tui, theme, _kb, done) => {
          const container = new Container();

          // Top border
          container.addChild(
            new DynamicBorder((s: string) => theme.fg("accent", s)),
          );

          // Header
          container.addChild(
            new Text(
              theme.fg(
                "accent",
                theme.bold("S3 Backups — ffmusiclibrary/prod/"),
              ),
              1,
              0,
            ),
          );
          container.addChild(new Text(theme.fg("muted", summary), 1, 0));

          // Spacer before list
          container.addChild(new Text(theme.fg("dim", "─".repeat(40)), 1, 0));

          // SelectList
          const selectList = new SelectList(items, Math.min(items.length, 20), {
            selectedPrefix: (t: string) => theme.fg("accent", t),
            selectedText: (t: string) => theme.fg("accent", t),
            description: (t: string) => theme.fg("muted", t),
            scrollInfo: (t: string) => theme.fg("dim", t),
            noMatch: (t: string) => theme.fg("warning", t),
          });
          selectList.onSelect = (item) => done(item.value);
          selectList.onCancel = () => done(null);
          container.addChild(selectList);

          // Footer hint
          container.addChild(
            new Text(
              theme.fg("dim", "↑↓ navigate  ·  enter select  ·  esc close"),
              1,
              0,
            ),
          );

          // Bottom border
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
              selectList.handleInput(data);
              tui.requestRender();
            },
          };
        },
      );

      if (selectedKey) {
        const obj = objects.find((o) => o.key === selectedKey);
        if (obj) {
          ctx.ui.notify(
            `${displayKey(obj.key)}  —  ${humanSize(obj.size)}  —  ${formatDate(obj.lastModified)}`,
            "info",
          );
        }
      }
    },
  });
}
