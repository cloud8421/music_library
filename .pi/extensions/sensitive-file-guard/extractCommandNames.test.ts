import { extractCommandNames } from "./ast.ts";

// --- Test runner ---
const blocked = new Set(["printenv", "env"]);

const tests: {
  cmd: string;
  expected: "BLOCKED" | "ALLOWED";
  reason: string;
}[] = [
  // Simple commands
  { cmd: "printenv", expected: "BLOCKED", reason: "Simple command match" },
  { cmd: "env FOO=bar", expected: "BLOCKED", reason: "Simple command match" },
  {
    cmd: "FOO=bar printenv",
    expected: "BLOCKED",
    reason: "Assignment prefix — printenv is still the command",
  },
  {
    cmd: "FOO=bar env",
    expected: "BLOCKED",
    reason: "Assignment prefix — env is still the command",
  },

  // Command substitution — blocked commands inside $() or backticks run
  { cmd: "$(env)", expected: "BLOCKED", reason: "Command substitution" },
  { cmd: "$(printenv)", expected: "BLOCKED", reason: "Command substitution" },
  {
    cmd: "`env`",
    expected: "BLOCKED",
    reason: "Backtick command substitution",
  },
  {
    cmd: "echo $(env)",
    expected: "BLOCKED",
    reason: "env inside command substitution in echo argument",
  },
  {
    cmd: "FOO=$(env) echo hi",
    expected: "BLOCKED",
    reason: "env inside command substitution in assignment value",
  },

  // Subshell
  { cmd: "(env)", expected: "BLOCKED", reason: "Subshell — env runs inside" },

  // Pipeline — any member triggers a block
  {
    cmd: "env | grep FOO",
    expected: "BLOCKED",
    reason: "Pipeline — env is first command",
  },
  {
    cmd: "grep FOO | env",
    expected: "BLOCKED",
    reason: "Pipeline — env is second command",
  },
  {
    cmd: "printenv | env",
    expected: "BLOCKED",
    reason: "Both blocked commands in pipeline",
  },

  // Compound lists and control flow
  {
    cmd: "for f in *; do env; done",
    expected: "BLOCKED",
    reason: "env in for loop body",
  },
  {
    cmd: "for f in $(env); do echo $f; done",
    expected: "BLOCKED",
    reason: "env in for wordlist command substitution",
  },
  {
    cmd: "for ((i=0;i<10;i++)); do env; done",
    expected: "BLOCKED",
    reason: "env in arithmetic for",
  },
  {
    cmd: "while true; do env; done",
    expected: "BLOCKED",
    reason: "env in while body",
  },
  {
    cmd: "until false; do env; done",
    expected: "BLOCKED",
    reason: "env in until body (parsed as While with kind:until)",
  },
  {
    cmd: "if true; then env; fi",
    expected: "BLOCKED",
    reason: "env in if-then",
  },
  {
    cmd: "case x in a) env;; esac",
    expected: "BLOCKED",
    reason: "env in case body",
  },
  {
    cmd: "case $(env) in a) echo hi;; esac",
    expected: "BLOCKED",
    reason: "env in Case.word substitution",
  },
  { cmd: "true && env", expected: "BLOCKED", reason: "env in AndOr (&&)" },
  {
    cmd: "select f in $(env); do echo $f; done",
    expected: "BLOCKED",
    reason: "env in select wordlist",
  },

  // Function definition, brace group, coproc
  {
    cmd: "foo() { env; }",
    expected: "BLOCKED",
    reason: "env in function body",
  },
  { cmd: "{ env; }", expected: "BLOCKED", reason: "env in brace group" },
  { cmd: "coproc env", expected: "BLOCKED", reason: "env in coproc body" },

  // --- ALLOWED: blocked command name is NOT at an executable position ---

  {
    cmd: "echo printenv",
    expected: "ALLOWED",
    reason: "printenv is an argument to echo, not a command",
  },
  { cmd: "# printenv", expected: "ALLOWED", reason: "Comment — not executed" },
  {
    cmd: 'echo "use env to..."',
    expected: "ALLOWED",
    reason: "Inside double-quoted string",
  },
  {
    cmd: "echo 'printenv'",
    expected: "ALLOWED",
    reason: "Inside single-quoted string",
  },
  {
    cmd: "(echo printenv)",
    expected: "ALLOWED",
    reason: "printenv is argument to echo inside subshell",
  },
  {
    cmd: "$(echo env)",
    expected: "ALLOWED",
    reason: "env is argument to echo inside command substitution",
  },
  {
    cmd: 'echo "use env" | grep FOO',
    expected: "ALLOWED",
    reason: "env in double-quoted string in pipeline",
  },

  // --- ALLOWED: command is not in the blocked set ---
  {
    cmd: "export FOO=bar",
    expected: "ALLOWED",
    reason: "export is not in blocked_commands",
  },
  {
    cmd: "ls -la",
    expected: "ALLOWED",
    reason: "ls is not in blocked_commands",
  },
  {
    cmd: "echo hi; echo there",
    expected: "ALLOWED",
    reason: "Semicolon-separated harmless commands",
  },
  {
    cmd: "echo hi || echo fail",
    expected: "ALLOWED",
    reason: "Or-separated harmless commands",
  },
  {
    cmd: "[[ -f file ]]",
    expected: "ALLOWED",
    reason: "TestCommand — no commands executed",
  },

  // --- ALLOWED: no command at all ---
  { cmd: "", expected: "ALLOWED", reason: "Empty command" },
  {
    cmd: "FOO=bar",
    expected: "ALLOWED",
    reason: "Bare assignment, no command name",
  },
  {
    cmd: ">/dev/null",
    expected: "ALLOWED",
    reason: "Redirection only, no command name",
  },
];

let passed = 0;
let failed = 0;

for (const { cmd, expected, reason } of tests) {
  const names = extractCommandNames(cmd);
  const hasBlocked = [...names].some((n) => blocked.has(n));
  const actual = hasBlocked ? "BLOCKED" : "ALLOWED";

  if (actual === expected) {
    passed++;
    console.log(`✅ ${expected.padEnd(7)} | ${cmd.padEnd(45)} | ${reason}`);
  } else {
    failed++;
    console.log(
      `❌ expected ${expected.padEnd(7)} got ${actual.padEnd(7)} | ${cmd.padEnd(45)} | ${reason}`,
    );
    console.log(`   Command names found: [${[...names].join(", ")}]`);
  }
}

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
