/**
 * Static regression tests for the prod-metrics extension entry point.
 *
 * The command registration previously used an unsupported object-shaped API and
 * ctx.openTui, which crashes current pi versions. Keep these assertions close to
 * the entry point so the test does not need to import pi runtime packages.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const indexSource = await readFile(
  new URL("./index.ts", import.meta.url),
  "utf8",
);

describe("prod-metrics extension entry point", () => {
  it("registers /prod-metrics with the supported command API", () => {
    assert.match(indexSource, /pi\.registerCommand\("prod-metrics",\s*\{/);
    assert.match(indexSource, /handler:\s*async \(_args, ctx\) =>/);
  });

  it("does not use the removed openTui command API", () => {
    assert.doesNotMatch(indexSource, /pi\.registerCommand\(\s*\{/);
    assert.doesNotMatch(indexSource, /ctx\.openTui/);
  });
});
