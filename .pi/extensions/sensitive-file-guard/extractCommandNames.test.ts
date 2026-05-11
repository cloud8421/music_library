/**
 * Tests for extractCommandNames from ast.ts using Node.js built-in node:test runner.
 *
 * Run with: node --experimental-strip-types --test extractCommandNames.test.ts
 */

import { describe, it } from "node:test";
import * as assert from "node:assert/strict";
import { extractCommandNames } from "./ast.ts";

// ── Test helpers ────────────────────────────────────────────────────────────

const blocked = new Set(["printenv", "env"]);

function checkBlocked(
  cmd: string,
  expected: "BLOCKED" | "ALLOWED",
  _reason: string,
): void {
  const names = extractCommandNames(cmd);
  const hasBlocked = [...names].some((n) => blocked.has(n));
  const actual = hasBlocked ? "BLOCKED" : "ALLOWED";
  assert.equal(
    actual,
    expected,
    `cmd: "${cmd}" — names found: [${[...names].join(", ")}]`,
  );
}

// ── BLOCKED: Simple commands ────────────────────────────────────────────────

describe("extractCommandNames — simple commands", () => {
  it("blocks a simple blocked command", () => {
    checkBlocked("printenv", "BLOCKED", "Simple command match");
  });

  it("blocks env with prefix assignment", () => {
    checkBlocked("env FOO=bar", "BLOCKED", "Simple command match");
  });

  it("blocks printenv with assignment prefix", () => {
    checkBlocked(
      "FOO=bar printenv",
      "BLOCKED",
      "Assignment prefix — printenv is still the command",
    );
  });

  it("blocks env with assignment prefix", () => {
    checkBlocked(
      "FOO=bar env",
      "BLOCKED",
      "Assignment prefix — env is still the command",
    );
  });
});

// ── BLOCKED: Command substitution ──────────────────────────────────────────

describe("extractCommandNames — command substitution", () => {
  it("blocks $(env)", () => {
    checkBlocked("$(env)", "BLOCKED", "Command substitution");
  });

  it("blocks $(printenv)", () => {
    checkBlocked("$(printenv)", "BLOCKED", "Command substitution");
  });

  it("blocks backtick env", () => {
    checkBlocked("`env`", "BLOCKED", "Backtick command substitution");
  });

  it("blocks env inside command substitution in echo argument", () => {
    checkBlocked(
      "echo $(env)",
      "BLOCKED",
      "env inside command substitution in echo argument",
    );
  });

  it("blocks env inside command substitution in assignment value", () => {
    checkBlocked(
      "FOO=$(env) echo hi",
      "BLOCKED",
      "env inside command substitution in assignment value",
    );
  });
});

// ── BLOCKED: Subshell ──────────────────────────────────────────────────────

describe("extractCommandNames — subshell", () => {
  it("blocks env in subshell", () => {
    checkBlocked("(env)", "BLOCKED", "Subshell — env runs inside");
  });
});

// ── BLOCKED: Pipeline ──────────────────────────────────────────────────────

describe("extractCommandNames — pipeline", () => {
  it("blocks env as first command in pipeline", () => {
    checkBlocked(
      "env | grep FOO",
      "BLOCKED",
      "Pipeline — env is first command",
    );
  });

  it("blocks env as second command in pipeline", () => {
    checkBlocked(
      "grep FOO | env",
      "BLOCKED",
      "Pipeline — env is second command",
    );
  });

  it("blocks both blocked commands in pipeline", () => {
    checkBlocked(
      "printenv | env",
      "BLOCKED",
      "Both blocked commands in pipeline",
    );
  });
});

// ── BLOCKED: Compound lists and control flow ───────────────────────────────

describe("extractCommandNames — compound lists and control flow", () => {
  it("blocks env in for loop body", () => {
    checkBlocked("for f in *; do env; done", "BLOCKED", "env in for loop body");
  });

  it("blocks env in for wordlist command substitution", () => {
    checkBlocked(
      "for f in $(env); do echo $f; done",
      "BLOCKED",
      "env in for wordlist command substitution",
    );
  });

  it("blocks env in arithmetic for", () => {
    checkBlocked(
      "for ((i=0;i<10;i++)); do env; done",
      "BLOCKED",
      "env in arithmetic for",
    );
  });

  it("blocks env in while body", () => {
    checkBlocked("while true; do env; done", "BLOCKED", "env in while body");
  });

  it("blocks env in until body (parsed as While with kind:until)", () => {
    checkBlocked(
      "until false; do env; done",
      "BLOCKED",
      "env in until body (parsed as While with kind:until)",
    );
  });

  it("blocks env in if-then", () => {
    checkBlocked("if true; then env; fi", "BLOCKED", "env in if-then");
  });

  it("blocks env in case body", () => {
    checkBlocked("case x in a) env;; esac", "BLOCKED", "env in case body");
  });

  it("blocks env in Case.word substitution", () => {
    checkBlocked(
      "case $(env) in a) echo hi;; esac",
      "BLOCKED",
      "env in Case.word substitution",
    );
  });

  it("blocks env in AndOr (&&)", () => {
    checkBlocked("true && env", "BLOCKED", "env in AndOr (&&)");
  });

  it("blocks env in select wordlist", () => {
    checkBlocked(
      "select f in $(env); do echo $f; done",
      "BLOCKED",
      "env in select wordlist",
    );
  });
});

// ── BLOCKED: Function definition, brace group, coproc ──────────────────────

describe("extractCommandNames — function, brace, coproc", () => {
  it("blocks env in function body", () => {
    checkBlocked("foo() { env; }", "BLOCKED", "env in function body");
  });

  it("blocks env in brace group", () => {
    checkBlocked("{ env; }", "BLOCKED", "env in brace group");
  });

  it("blocks env in coproc body", () => {
    checkBlocked("coproc env", "BLOCKED", "env in coproc body");
  });
});

// ── ALLOWED: Blocked name at non-executable position ───────────────────────

describe("extractCommandNames — blocked name not at executable position", () => {
  it("allows printenv as argument to echo", () => {
    checkBlocked(
      "echo printenv",
      "ALLOWED",
      "printenv is an argument to echo, not a command",
    );
  });

  it("allows printenv in comment", () => {
    checkBlocked("# printenv", "ALLOWED", "Comment — not executed");
  });

  it("allows env in double-quoted string", () => {
    checkBlocked(
      'echo "use env to..."',
      "ALLOWED",
      "Inside double-quoted string",
    );
  });

  it("allows printenv in single-quoted string", () => {
    checkBlocked("echo 'printenv'", "ALLOWED", "Inside single-quoted string");
  });

  it("allows printenv as argument to echo inside subshell", () => {
    checkBlocked(
      "(echo printenv)",
      "ALLOWED",
      "printenv is argument to echo inside subshell",
    );
  });

  it("allows env as argument to echo inside command substitution", () => {
    checkBlocked(
      "$(echo env)",
      "ALLOWED",
      "env is argument to echo inside command substitution",
    );
  });

  it("allows env in double-quoted string in pipeline", () => {
    checkBlocked(
      'echo "use env" | grep FOO',
      "ALLOWED",
      "env in double-quoted string in pipeline",
    );
  });
});

// ── ALLOWED: Command not in blocked set ────────────────────────────────────

describe("extractCommandNames — command not in blocked set", () => {
  it("allows export", () => {
    checkBlocked(
      "export FOO=bar",
      "ALLOWED",
      "export is not in blocked_commands",
    );
  });

  it("allows ls", () => {
    checkBlocked("ls -la", "ALLOWED", "ls is not in blocked_commands");
  });

  it("allows semicolon-separated harmless commands", () => {
    checkBlocked(
      "echo hi; echo there",
      "ALLOWED",
      "Semicolon-separated harmless commands",
    );
  });

  it("allows OR-separated harmless commands", () => {
    checkBlocked(
      "echo hi || echo fail",
      "ALLOWED",
      "Or-separated harmless commands",
    );
  });

  it("allows TestCommand ([[ ... ]])", () => {
    checkBlocked(
      "[[ -f file ]]",
      "ALLOWED",
      "TestCommand — no commands executed",
    );
  });
});

// ── ALLOWED: No command at all ─────────────────────────────────────────────

describe("extractCommandNames — no command at all", () => {
  it("allows empty command", () => {
    checkBlocked("", "ALLOWED", "Empty command");
  });

  it("allows bare assignment with no command name", () => {
    checkBlocked("FOO=bar", "ALLOWED", "Bare assignment, no command name");
  });

  it("allows redirection only with no command name", () => {
    checkBlocked(">/dev/null", "ALLOWED", "Redirection only, no command name");
  });
});
