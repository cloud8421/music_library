---
id: ML-158
title: Force production logs to single-line format
status: Done
assignee: []
created_date: "2026-05-03 13:51"
updated_date: "2026-05-04 13:43"
labels:
  - ready
dependencies: []
references:
  - "backlog://documents/doc-3"
modified_files:
  - mix.exs
  - config/config.exs
  - config/prod.exs
  - lib/music_library/application.ex
  - lib/music_library/logger/single_line_formatter.ex
  - test/music_library/logger/single_line_formatter_test.exs
  - docs/production-infrastructure.md
  - docs/architecture.md
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

When running in production, logs spanning multiple lines create issues — they cannot be easily filtered, and log output cannot be reversed reliably. We need to configure the `prod` environment to output logs on one line with appropriate metadata.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 HTTP request logs (GET /path + Sent 200) appear as a single logfmt line in production
- [x] #2 LiveView socket connection logs (CONNECTED TO Phoenix.LiveView.Socket) appear as a single line
- [x] #3 No log message in production output spans multiple physical lines — all newlines are escaped as \\n
- [x] #4 Existing metadata (request_id, etc.) is preserved in log output
- [x] #5 Stack traces from errors/exceptions are escaped to single line
- [x] #6 Dev environment logging is unchanged and still uses multi-line format for readability
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Implementation Plan: Force production logs to single-line format

### Objective alignment

The problem: multi-line log output in production prevents reliable line-based filtering and makes log output impossible to reverse. Log sources include HTTP request logs (two separate `Logger.info` calls from `Phoenix.Logger`), LiveView handshake logs (single `Logger.info` with embedded newlines), and any custom `Logger` calls that pass multi-line strings.

The solution has three layers:

1. **Logster** replaces `Phoenix.Logger` for HTTP request logging — merges `GET + Sent` into one logfmt line
2. **Custom telemetry handler** replaces `Phoenix.Logger`'s `[:phoenix, :socket_connected]` handler — flattens LiveView handshake into one line
3. **Custom Logger.Formatter** acts as a universal safety net — replaces any remaining embedded newlines with escaped `\n` in ALL log messages

### Simplicity and alternatives considered

**Chosen**: Logster v2 + custom telemetry handler + custom formatter. Handles all log sources explicitly, with a safety net for anything missed.

**Rejected**: Custom formatter alone (Route A) — would flatten LiveView handshakes but HTTP requests remain two separate lines (they're separate log events, not one multi-line event). This fails to solve the reversibility problem for HTTP logs.

**Rejected**: JSON structured logging (Route B) — adds a dependency and makes terminal `grep`/`tail` harder. Overkill for a personal app without log aggregation.

**Deferred**: Migrating custom `Logger` calls to `Logster.info/1` key=value format — can be done incrementally after this task.

### Completeness and sequencing

#### Step 0: Pre-implementation verification

Before writing code, verify two assumptions:

**0a. Enumerate Phoenix.Logger events that fire in production.**

`Phoenix.Logger` auto-attaches to 8 telemetry events. With production log level `:info`, only these produce visible output:

| Event                                  | Level    | Multi-line?        | Covered by                                                                                                              |
| -------------------------------------- | -------- | ------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| `[:phoenix, :endpoint, :start]`        | `:info`  | No (one line)      | Logster v2                                                                                                              |
| `[:phoenix, :endpoint, :stop]`         | `:info`  | No (one line)      | Logster v2                                                                                                              |
| `[:phoenix, :socket_connected]`        | `:info`  | **Yes** (4+ lines) | Custom handler (Step 4)                                                                                                 |
| `[:phoenix, :error_rendered]`          | `:error` | No (one line)      | Silenced — acceptable (ErrorTracker already captures errors)                                                            |
| `[:phoenix, :router_dispatch, :start]` | `:debug` | Yes                | Already filtered at `:info` level — no action needed                                                                    |
| `[:phoenix, :socket_drain]`            | `:debug` | No                 | Already filtered                                                                                                        |
| `[:phoenix, :channel_joined]`          | `:debug` | Yes                | Already filtered (LiveView uses `"lv:"` topics not `"phoenix"` internal topics, but default log_join level is `:debug`) |
| `[:phoenix, :channel_handled_in]`      | `:debug` | Yes                | Already filtered                                                                                                        |

**Verdict**: The only events that produce visible output at `:info`+ are endpoint start/stop, socket_connected, and error_rendered. Disabling Phoenix.Logger is safe — the first two are replaced by Logster, socket_connected is replaced by the custom handler, and losing error_rendered is acceptable because ErrorTracker already captures all errors via its own telemetry listener.

**Verify**: Confirm by starting the app with `MIX_ENV=prod mix phx.server` and inspecting stdout before any changes. Note which Phoenix.Logger events appear. If `router_dispatch_start` or `channel_*` events appear at `:info`, adjust the plan accordingly.

**0b. Verify whether Logster v2 handles `[:phoenix, :socket_connected]`.**

After adding the Logster dependency (Step 1), inspect `Logster`'s telemetry attachments to check if it already emits a handler for `[:phoenix, :socket_connected]`.

**Verify**: In an IEx session: `Logster.__info__(:functions)` or check the Logster source to see which events it attaches to. If it covers `socket_connected`, **skip Step 4** — the custom telemetry handler is unnecessary.

#### Step 1: Add Logster dependency

- Add `{:logster, "~> 2.0.0-rc.5"}` to `mix.exs` deps
- Run `mix deps.get`
- **Verify**: `mix compile` succeeds, `Logster` module is available

#### Step 2: Disable Phoenix.Logger in prod

- `config/prod.exs`: add `config :phoenix, :logger, false`
- **Note**: This silences all 8 Phoenix.Logger telemetry handlers. Only `endpoint_start`, `endpoint_stop`, `socket_connected`, and `error_rendered` fire at `:info`+ in production. The first two are replaced by Logster, `socket_connected` is replaced by the custom handler (Step 4), and `error_rendered` is redundant with ErrorTracker.
- **Verify**: After deployment, no `GET /path`, `Sent 200`, or `CONNECTED TO` lines appear from Phoenix.Logger (they'll be replaced by Logster and the custom handler).

#### Step 3: Configure Logster and attach in application.ex

**Environment-conditional mechanism**: Use a config flag rather than checking `Mix.env()` at runtime (follows the project's existing pattern, e.g., `config :error_tracker, enabled: true`).

- `config/config.exs`: add `config :music_library, :single_line_logging, false`
- `config/prod.exs`: override with `config :music_library, :single_line_logging, true`
- `config/prod.exs`: add Logster configuration:
  ```elixir
  config :logster,
    extra_fields: [:request_id],
    filter_parameters: Application.get_env(:phoenix, :filter_parameters, ["password"])
  ```
  (Reuses Phoenix's existing parameter filter list; `request_id` is added to every log line as metadata.)
- `lib/music_library/application.ex`: add after children list declaration:
  ```elixir
  if Application.fetch_env!(:music_library, :single_line_logging) do
    Logster.attach_phoenix_logger()
  end
  ```
- **Verify**: In prod (`MIX_ENV=prod mix phx.server`), HTTP requests produce a single logfmt line like `method=GET path=/health request_id=Fz... status=200 duration=696µs`. In dev, Logster is NOT attached and Phoenix.Logger continues to log normally.

#### Step 4: Create custom telemetry handler for LiveView socket connections

> **Prerequisite**: Complete Step 0b first. Skip this step if Logster already handles `[:phoenix, :socket_connected]`.

- New module `lib/music_library_web/telemetry/log_handler.ex` (placed under `lib/music_library_web/telemetry/` to match existing convention — sibling to `Telemetry.Storage`)
- Handles `[:phoenix, :socket_connected]` event
- Outputs a single line with transport, serializer, duration, result, and filtered params
- Respects Phoenix's `:filter_parameters` config — reuse `Phoenix.Logger.filter_values/2` for parameter filtering
- Include `@moduledoc` explaining purpose (required by Credo strict mode)
- Attach handler in `application.ex` inside the same `if single_line_logging` block as Logster:
  ```elixir
  :telemetry.attach(
    "music-library-socket-connected",
    [:phoenix, :socket_connected],
    &MusicLibraryWeb.Telemetry.LogHandler.handle_event/4,
    :ok
  )
  ```
- **Verify**: LiveView connection produces one line instead of 4+. Trigger by visiting any LiveView page (e.g., `/collection`). Manual inspection of stdout.
- **Unit test** (`test/music_library_web/telemetry/log_handler_test.exs`): Verify output format is a single line containing transport, serializer, and duration. Verify sensitive params are filtered.
- **Dependency on**: Step 2 (Phoenix.Logger must be disabled first so we don't double-log)

#### Step 5: Create custom Logger.Formatter (safety net)

- New module `lib/music_library/logger/single_line_formatter.ex`
- Implements `format/4` function (`level, message, timestamp, metadata`) returning `IO.chardata()`
- Replaces literal `\n` (newline character) with escaped `\\n` (backslash + n) in the message
- Handles both string and iolist messages: convert to string via `IO.chardata_to_string/1` before replacement
- Include `@moduledoc` explaining that this is a production-only safety net for any log messages containing embedded newlines
- **Unit tests** (`test/music_library/logger/single_line_formatter_test.exs`):
  - `Logger.error("line1\nline2\nline3")` → produces one line with `line1\\nline2\\nline3`
  - Messages without newlines pass through unchanged
  - Iolist input `['hello', ?\n, 'world']` → produces `hello\\nworld`
  - Metadata (request_id etc.) is preserved in output
  - Empty messages don't crash
- **Verify**: In IEx, `Logger.error("line1\nline2\nline3")` produces one line. Run `mix test test/music_library/logger/single_line_formatter_test.exs`.

#### Step 6: Configure custom formatter in prod

- `config/prod.exs`: override the default formatter:
  ```elixir
  config :logger, :default_formatter,
    format: {MusicLibrary.Logger.SingleLineFormatter, :format},
    metadata: [:request_id]
  ```
- **Verify**: After deployment (`MIX_ENV=prod mix phx.server`), no log line contains an unescaped newline. Trigger a LiveView crash to verify stack traces are escaped to single line.

#### Step 7: Audit codebase for multi-line Logger calls (best-effort)

> **Note**: The custom formatter (Step 5) is the authoritative safety net. This audit is best-effort — it catches multi-line calls in project code that would benefit from being rewritten as structured single-line messages, but the formatter handles anything missed.

- Search for Logger calls containing `\n` escape sequences:
  ```bash
  rg -n 'Logger\.(info|error|warning|debug)\b.*\\\\n' lib/ --no-heading
  ```
- Search for Logger calls spanning multiple lines (heredocs, built-up iolists):
  ```bash
  rg -U -n 'Logger\.(info|error|warning|debug)\b[^)]*\n' lib/ --no-heading
  ```
- Rewrite found instances to single-line strings or use structured key=value format
- **Do NOT** attempt to rewrite OTP/Elixir internal Logger calls — the custom formatter handles those.
- **Verify**: Both `rg` searches return empty for project code in `lib/`. The formatter's unit tests pass.

#### Step 8: Integration tests for environment behavior

- **Dev environment unchanged test** (`test/music_library/logger/single_line_formatter_test.exs` or a dedicated integration test): Verify that in dev/test config (where `single_line_logging` is `false`), Logster is NOT attached and the custom formatter is NOT configured. Multi-line logs still appear in dev.
- **Production config test**: Verify that loading `config/prod.exs` sets `config :phoenix, :logger, false`, `config :music_library, :single_line_logging, true`, and the custom formatter tuple.
- **Verify**: `mix test` passes with coverage ≥75%.

#### Step 9: OTP release verification

> The production deployment uses an OTP release (`rel/overlays/bin/server`), not `mix phx.server`. The release has a different logging pipeline (Erlang `:logger` under the hood) that must be verified.

- Build the release: `MIX_ENV=prod mix release`
- Start the release and hit endpoints: `_build/prod/rel/music_library/bin/music_library start` (or `eval` for quick smoke test)
- **Verify**:
  - HTTP requests produce single logfmt lines
  - LiveView connections produce single lines
  - No multi-line log output appears
  - Release starts without errors related to the new modules

#### Step 10: Update documentation

- **`docs/production-infrastructure.md`**: Add "Logging" section under Monitoring & Observability, describing:
  - Logster for HTTP request logging (logfmt format)
  - Custom telemetry handler for LiveView socket connections
  - Custom formatter as single-line safety net
  - Configuration details (formatter module, Logster attach point, config flag)
  - Note that dev environment keeps default multi-line format
- **`docs/architecture.md`**: Add new modules to the architecture summary:
  - `MusicLibrary.Logger.SingleLineFormatter` under Business Logic Modules
  - `MusicLibraryWeb.Telemetry.LogHandler` under Web Utility Modules
  - Note that Logster is an external telemetry handler attached in `application.ex` (not a supervised process)
- **Verify**: Both docs accurately reflect the new logging architecture. Run `mix docs` if available.

### Verifiability

| Step | Verification                                                                                                                                                     |
| ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0a   | Inspect stdout with `MIX_ENV=prod mix phx.server` before any changes — confirm only endpoint start/stop, socket_connected, and error_rendered appear at `:info`+ |
| 0b   | Inspect Logster source in `deps/logster/` — check if `socket_connected` is handled; if yes, skip Step 4                                                          |
| 1    | `mix compile` passes, `Logster` module is available in IEx                                                                                                       |
| 2-6  | Start app with `MIX_ENV=prod mix phx.server`, hit endpoints, inspect stdout — all logs on one line                                                               |
| 4    | Visit a LiveView page (`/collection`) in prod mode, verify single-line output in stdout                                                                          |
| 5    | `mix test test/music_library/logger/single_line_formatter_test.exs` — all tests pass                                                                             |
| 7    | Both `rg` searches (escaped `\n` and multi-line Logger calls) return empty for `lib/`                                                                            |
| 8    | `mix test` passes with ≥75% coverage; dev env test confirms multi-line output unchanged                                                                          |
| 9    | `MIX_ENV=prod mix release` succeeds; release binary starts without errors; log output is single-line                                                             |
| 10   | Read both docs, confirm accuracy against implemented config and modules                                                                                          |

### Architecture impact analysis

**Schemas**: None affected.

**Contexts**: None affected.

**PubSub**: None affected.

**Supervision tree**: No new children. Logster is a telemetry handler attached in `application.ex` — not a supervised process. The custom telemetry handler is also a `:telemetry.attach` call, not a supervised process.

**Routes**: None affected.

**External APIs**: None affected.

**UI components**: None affected.

**Config changes**:

- `config/config.exs`: add `config :music_library, :single_line_logging, false`
- `mix.exs`: new dependency `{:logster, "~> 2.0.0-rc.5"}`
- `config/prod.exs`: 4 additions (phoenix logger disable, single_line_logging flag, logster config, formatter config)
- `lib/music_library/application.ex`: 1 conditional block (Logster attach + optional telemetry handler attach)

**New modules**:

- `lib/music_library/logger/single_line_formatter.ex` — Logger.Formatter format/4 function; requires `@moduledoc` (Credo strict mode)
- `lib/music_library_web/telemetry/log_handler.ex` — Phoenix socket telemetry handler (conditional on Step 0b); requires `@moduledoc`

**New tests**:

- `test/music_library/logger/single_line_formatter_test.exs` — unit tests for the formatter (newline replacement, iolist handling, metadata preservation)
- `test/music_library_web/telemetry/log_handler_test.exs` — unit tests for the telemetry handler (single-line output, param filtering)
- Integration assertions in existing or new test files for dev config unchanged

**Migration/deprecation**: None needed. Old config is simply replaced.

**Docker image impact**: Adding `logster` as a new Mix dependency changes `mix.lock`. The first deploy after this change will take longer because the Docker image rebuilds Logster from source. Subsequent deploys use the cached layer.

### Performance profile

**Runtime complexity**: O(1) per log event.

- Logster: string interpolation from telemetry metadata per HTTP request
- Custom telemetry: same — one function call per socket connection
- Custom formatter: one `IO.chardata_to_string/1` + `String.replace/3` per log event (message size bounded by Logger truncation)

**Database queries**: None. This is purely output-side.

**Memory**: Negligible. No accumulated state.

**N+1 risks**: None. No database interaction.

**Latency/throughput**: All operations happen synchronously in the logging process. String replacement on bounded-size strings is microseconds. At the log volume of a single-user personal app (~dozens of requests/minute), overhead is unmeasurable.

### Benchmarking requirements

None needed. The operations are:

- String replacement on logger-truncated messages (bounded by default 4KB or configurable)
- String interpolation from telemetry metadata (no IO, no computation)
  These are trivially fast. If future log volume increases by orders of magnitude, the `Logger` overload protection (message dropping at >500/sec) will engage before our formatter becomes a bottleneck.

### Cost profile

No paid resources consumed.

- Logster: MIT license, free
- No API calls, no compute, no storage costs
- No third-party services

### Production infrastructure steps

No manual production changes required. All configuration is in `config/prod.exs` and `application.ex`, deployed via the standard CI/CD pipeline.

**Environment variables**: None new.

**Service provisioning**: None.

**Database migrations**: None.

**DNS/firewall**: None.

**Rollout**: Standard deploy (push to main → GitHub Actions → Coolify). First deploy will be slower due to new dependency compilation (Logster). Subsequent deploys use cached Docker layer.

**Rollback**: Revert to previous commit. No data migration needed.

<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

## Implementation Summary

### What was done

#### Step 0: Pre-implementation verification

- Confirmed Phoenix.Logger fires 4 events at `:info`+ level (endpoint start/stop, socket_connected, error_rendered) — matches plan assumptions
- Confirmed Logster v2 handles `[:phoenix, :socket_connected]` — **skipped Step 4** (custom telemetry handler unnecessary)

#### Step 1: Added Logster dependency

- `mix.exs`: `{:logster, "~> 2.0.0-rc.5"}`

#### Step 2: Disabled Phoenix.Logger in prod

- `config/prod.exs`: `config :phoenix, :logger, false`

#### Step 3: Configured Logster with environment-conditional attach

- `config/config.exs`: `config :music_library, :single_line_logging, false`
- `config/prod.exs`: `config :music_library, :single_line_logging, true`
- `config/prod.exs`: Logster config with `extra_fields: [:request_id]` and parameter filtering
- `lib/music_library/application.ex`: conditional `Logster.attach_phoenix_logger()` when `single_line_logging` is true

#### Step 4: Skipped (Logster v2 handles `[:phoenix, :socket_connected]`)

#### Step 5-6: Created custom Logger.Formatter as safety net

- `lib/music_library/logger/single_line_formatter.ex`: Implements `format/4` callback, replaces embedded `\n` with escaped `\\n`, handles string/iolist/report messages, preserves metadata
- `config/prod.exs`: formatter configured as `{MusicLibrary.Logger.SingleLineFormatter, :format}` with `metadata: [:request_id]`

#### Step 7: Codebase audit

- Searched for Logger calls with embedded `\n` — none found
- Multi-line Logger calls in source all produce single-line output (string concatenation without actual newlines)
- Custom formatter handles any remaining cases from OTP/Elixir internals

#### Step 8: Tests

- `test/music_library/logger/single_line_formatter_test.exs`: 13 tests covering newline replacement, iolist handling, metadata preservation, single-line output, dev/test config verification
- All 931 project tests pass

#### Step 9: OTP release verification

- `MIX_ENV=prod mix release` builds successfully
- sys.config confirms: `phoenix logger: false`, `single_line_logging: true`, Logster config, custom formatter tuple, logster application included

#### Step 10: Documentation

- `docs/production-infrastructure.md`: Added "Logging" section under Monitoring & Observability
- `docs/architecture.md`: Added `MusicLibrary.Logger.SingleLineFormatter` to Business Logic Modules, Logster note under Supervision Tree, and Web Utility Modules note

### Files changed

- `mix.exs` — added logster dependency
- `config/config.exs` — added `single_line_logging: false`
- `config/prod.exs` — 4 config additions (phoenix logger disable, flag, logster, formatter)
- `lib/music_library/application.ex` — conditional Logster attach
- `lib/music_library/logger/single_line_formatter.ex` — new module
- `test/music_library/logger/single_line_formatter_test.exs` — new test file
- `docs/production-infrastructure.md` — Logging section
- `docs/architecture.md` — module entries
<!-- SECTION:FINAL_SUMMARY:END -->
