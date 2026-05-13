---
description: Perform an application-wide security review
---

You are a senior application security engineer. Audit the Elixir application in
the current working directory for real, exploitable vulnerabilities.

Use the tools available to you (Read, Grep, Glob, Bash) to explore the
codebase, follow data flow across modules, inspect call graphs, and check
commit history (`git log --all --grep`, `git log -S`) for unpatched variants
of past bugs. Spend effort proportional to the package's risk surface.

## Methodology

Two phases. Phase 1 is an inventory — write it down before judging anything.
Two runs against the same source should produce the same inventory.

### Phase 1: Boundaries + inventory

Before listing sinks, name the trust boundaries. For a small library this
is one or two lines: who calls it, what they pass, where external data
enters. Larger codebases get a table — actor, what they control, trusted
yes/no, where you found it documented. The per-sink boundary check in
Phase 2 references this list; it does not re-derive boundaries per sink.

Then enumerate every sink. For each: file, line, sink class, what it
consumes. Don't judge any of them yet — a sink is dangerous-if-input-is-
hostile, regardless of whether you currently think the input is hostile.
Grep exhaustively for the language's primitives in each class.

### Phase 2: Per-sink — six steps in order

Stop when a step rules the sink out and record which step did. Every
inventory sink ends up either in `findings` or in `ruled_out`.

1. Trace — backwards from sink to a boundary. Name each hop. If the
   value never crosses a boundary, write "internal" and stop.
2. Boundary — which boundary from Phase 1 does it cross? The library
   caller is not the attacker; documented config / operator-set values
   are trusted unless the docs say otherwise. Cite the doc. Also: check
   a precondition does not subsume the conclusion (an attack that
   requires write access to a directory whose contents are documented
   as executable is circular).
3. Validate — write a reproduction script. For Elixir, a short `.exs`
   under `scripts/{package_name}/{short_description}.exs` runnable via
   `Mix.install` is ideal. DO NOT execute it; the human will. Paste the
   script in the `validation` field. For round-trip pairs, the script
   runs `decode(encode(x))` and `encode(decode(s))` with structural
   characters and shows the asymmetry.
4. Prior art — `git log --all --grep` and `git log -S` for the function
   name and key strings; read closed issues/PRs; check whether the
   behaviour is required by an RFC. If a maintainer already declined,
   quote the comment.
5. Reach — for libraries: which kind of consumer would wire hostile
   input here. You don't have dependents data; reason about plausible
   call patterns. "No plausible exposed caller" is data, not a verdict.
6. Rate — severity + confidence. Critical = works on a fresh install,
   no preconditions. High = realistic preconditions a normal deployment
   satisfies. Medium = significant attacker positioning, unusual config,
   or a chain. Low = unrealistic preconditions or narrow impact.

## Always-flag

Some sinks are dangerous enough on sight that the trace/boundary check is
skipped — flag every occurrence as a finding even if you can't trace where
the input comes from.

- **`:erlang.binary_to_term/1`, or `:erlang.binary_to_term/2` without
  `:safe` in the options list.** Untrusted-binary deserialisation creates
  arbitrary atoms (atom-table exhaustion DoS), can construct fun /
  reference / pid terms that crash or hijack callers, and bypasses
  parse-time validation entirely. The safe alternatives are
  `:erlang.binary_to_term(bin, [:safe])` and
  `Plug.Crypto.non_executable_binary_to_term/2`. Severity: **Critical**.
  Report once per call site. If the same module also exposes the wrapper
  that reaches the call site, mention the wrapper in the trace, but do
  not skip the finding for lack of a traced caller.

- **`:erlang.binary_to_term/2` with `:safe`.** `:safe` blocks new atoms
  and funs, but the decoded term is still attacker-shaped: deeply nested
  structures cause memory amplification, existing atoms can still be
  referenced (so any atom the BEAM has loaded is fair game), and callers
  that pattern-match on a specific shape can crash or be confused. Worth
  a note so reviewers can confirm the caller validates the result.
  Severity: **Low**.

Sink classes — every place dangerous logic could live, regardless of whether
the input currently looks hostile. Enumerate first, judge second.

- Code execution — eval, dynamic dispatch on a computed name (`apply`,
  `Code.eval_*`, `:erlang.apply/3` with computed args), code loaded from a
  computed path, regex with embedded-code constructs.
- Command execution — `System.cmd`, `:os.cmd`, `Port.open({:spawn, …})`,
  shelling out where args are built by concatenation rather than passed as
  a list.
- File operations — `File.read/write/rm/cp/ln/chmod` where the path is
  computed; `Code.require_file` / `Code.eval_file` with dynamic paths.
- Path handling — `Path.join/expand/relative_to`, traversal, symlink
  following, case-fold confusion on case-insensitive filesystems.
- Archive extraction — `:erl_tar`, `:zip`, any unpack where entry names
  become filesystem paths (zip-slip).
- Deserialisation — `:erlang.binary_to_term/1` (no `:safe`),
  `Plug.Crypto.non_executable_binary_to_term/2` misuse, YAML/Marshal-style
  formats that instantiate types during parse.
- Template / interpolation — values reaching another interpreted context
  without escaping for it: HTML, SQL via raw fragments, EEx/Phoenix
  `raw/1`, shell, regex, format strings, log lines.
- Network — clients that follow redirects, accept URLs from input, resolve
  hostnames from data, TLS verification disabled (`verify: :verify_none`),
  proxy handling.
- Validation — predicates whose contract is "this is safe": the sink is
  the return value, the danger is returning the wrong answer.
- Cryptography — KDF parameters, IV reuse, mode/padding, MAC verification,
  `==` on secrets instead of `Plug.Crypto.secure_compare/2`.
- Memory safety — Rust `unsafe`, raw pointers, unchecked indexing, FFI,
  transmute. For NIFs: lifetime/aliasing across the BEAM boundary.
- Shared mutable state — `Application.put_env/3` from input, ETS/DETS,
  `:persistent_term`, environment variables, signal handlers, Logger
  backends. One input poisoning what another sees.
- Concurrency — check-then-act sequences a racer can interleave: file
  existence before open, permission before access, GenServer state read
  then written without serialisation.
- Resource consumption — atom leaks (`String.to_atom/1` on input),
  unbounded loops/allocs, regex prone to catastrophic backtracking,
  decompression with attacker-controlled ratio.
- Reflection / metaprogramming gadgets the library installs into the
  caller — `__using__` macros, `@before_compile`, telemetry handler
  attaches, Logger backends, monkeypatched callbacks. The library _chose_
  to install the gadget; consumer wiring is a reach question, not a
  reason to drop the sink.
- Round-trip integrity — pairs meant to be inverses: `encode`/`decode`,
  `parse`/`serialize`, `marshal`/`unmarshal`. The sink is the pair. The
  danger is asymmetry — if `decode(encode(x)) ≠ x`, or encode emits raw
  what decode interprets, a value can change meaning across a store-and-
  reload cycle and bypass parse-time validation on re-parse.

## Output

Always output the full report — boundaries and inventory must be present
even when nothing rises to a finding. Format:

    ## Trust boundaries

    | Actor | Trusted | Controls | Source |
    |-------|---------|----------|--------|
    | <name> | yes/no/conditional | <what they control> | <doc citation> |

    ## Inventory

    | ID | Location | Class | Consumes |
    |----|----------|-------|----------|
    | S1 | <rel/path>:<line> or <rel/path>:<line_start>-<line_end> | <sink class> | <what it consumes> |

    ## Findings

    ### F1 — <short title>
    **Severity:** Critical | High | Medium | Low
    **CWE:** CWE-NNN
    **Location:** <rel/path>:<line> | <rel/path>:<line_start>-<line_end>
    **Sinks:** S1[, S2…]

    **Trace:** <markdown>

    **Boundary:** <markdown>

    **Validation:** <markdown — include the reproduction script verbatim
    under a fenced code block. Do NOT execute it; the human will.>

    **Prior art:** <markdown — git log / issues / RFC citations>

    **Reach:** <markdown — plausible exposed callers>

    **Rating:** <markdown — severity + confidence rationale>

    **Suggested fix:** <one or two sentences>

    ## Ruled out

    - **S2, S3** (step N) — <one or two sentences>

Use `## Findings\n\n_None._` for a clean report — never omit the section.
Every inventory sink ID must appear in either `Findings → Sinks:` or in
the `Ruled out` list. No preamble, no overall summary, no closing notes.
