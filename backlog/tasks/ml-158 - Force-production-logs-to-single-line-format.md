---
id: ML-158
title: Force production logs to single-line format
status: To Do
assignee: []
created_date: '2026-05-03 13:51'
updated_date: '2026-05-03 14:26'
labels: []
dependencies: []
references:
  - 'backlog://documents/doc-3'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When running in production, logs spanning multiple lines create issues — they cannot be easily filtered, and log output cannot be reversed reliably. We need to configure the `prod` environment to output logs on one line with appropriate metadata.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 HTTP request logs (GET /path + Sent 200) appear as a single logfmt line in production
- [ ] #2 LiveView socket connection logs (CONNECTED TO Phoenix.LiveView.Socket) appear as a single line
- [ ] #3 No log message in production output spans multiple physical lines — all newlines are escaped as \\n
- [ ] #4 Existing metadata (request_id, etc.) is preserved in log output
- [ ] #5 Stack traces from errors/exceptions are escaped to single line
- [ ] #6 Dev environment logging is unchanged and still uses multi-line format for readability
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

#### Step 1: Add Logster dependency
- Add `{:logster, "~> 2.0.0-rc.5"}` to `mix.exs` deps
- Run `mix deps.get`
- **Verify**: `mix compile` succeeds, `Logster` module is available

#### Step 2: Disable Phoenix.Logger and configure Logster in prod
- `config/prod.exs`: add `config :phoenix, :logger, false`
- `config/prod.exs`: add Logster configuration (filter parameters, optional settings)
- **Verify**: After deployment, no `GET /path` or `Sent 200 in Xms` lines appear (they'll be replaced by Logster's output)

#### Step 3: Attach Logster in application.ex
- `lib/music_library/application.ex`: add conditional `Logster.attach_phoenix_logger()` for `:prod` env
- **Verify**: In prod, HTTP requests produce a single logfmt line like `method=GET path=/health ... status=200 duration=696`

#### Step 4: Create custom telemetry handler for LiveView socket connections
- New module `lib/music_library_web/telemetry_log_handler.ex`
- Handles `[:phoenix, :socket_connected]` event
- Outputs a single line with transport, serializer, duration, and filtered params
- Attach handler in `application.ex` (prod-only) alongside Logster
- **Verify**: LiveView connection produces one line instead of 4+
- **Dependency on**: Step 2 (Phoenix.Logger must be disabled first so we don't double-log)

#### Step 5: Create custom Logger.Formatter (safety net)
- New module `lib/music_library/logger/single_line_formatter.ex`
- Implements `format/4` function for `{module, function}` Logger.Formatter API
- Replaces `\n` with `\n` in message before delegating to default formatter
- **Verify**: Any Logger call with embedded newlines (stack traces, OTP reports) produces one line. Test with `Logger.error("line1\nline2\nline3")`

#### Step 6: Configure custom formatter in prod
- `config/prod.exs`: set `config :logger, :default_formatter, format: {MusicLibrary.Logger.SingleLineFormatter, :format}`
- Keep `metadata: [:request_id]`
- **Verify**: After deployment, no log line contains an unescaped newline

#### Step 7: Audit codebase for multi-line Logger calls
- Search for `Logger.` calls with string interpolation containing `\n`
- Rewrite to single-line strings or use `Logster.info/1` style
- **Verify**: `rg 'Logger\.(info|error|warning|debug)\b.*\\n' lib/` returns empty

#### Step 8: Update documentation
- Update `docs/production-infrastructure.md` — add logging section describing the three-layer approach
- **Verify**: Docs reflect the new logging architecture

### Verifiability

| Step | Verification |
|---|---|
| 1 | `mix compile` passes |
| 2-6 | Start app with `MIX_ENV=prod mix phx.server`, hit endpoints, inspect stdout — all logs on one line |
| 4 | Trigger LiveView connection (visit a LiveView page), verify single-line output |
| 5 | `mix test` for any new unit tests, manual inspection of crash logs |
| 7 | `rg` search returns empty |
| 8 | Read docs, confirm accuracy |

### Architecture impact analysis

**Schemas**: None affected.

**Contexts**: None affected.

**PubSub**: None affected.

**Supervision tree**: No new children. Logster is a telemetry handler attached in `application.ex` — not a supervised process.

**Routes**: None affected.

**External APIs**: None affected.

**UI components**: None affected.

**Config changes**:
- `mix.exs`: new dependency
- `config/prod.exs`: 3 additions (phoenix logger disable, logster config, formatter config)
- `lib/music_library/application.ex`: 1 addition (Logster attach call + telemetry handler attach)

**New modules**:
- `lib/music_library/logger/single_line_formatter.ex` — Logger.Formatter format function
- `lib/music_library_web/telemetry_log_handler.ex` — Phoenix socket telemetry handler

**Migration/deprecation**: None needed. Old config is simply replaced.

### Performance profile

**Runtime complexity**: O(1) per log event.
- Logster: string interpolation from telemetry metadata per HTTP request
- Custom telemetry: same — one function call per socket connection
- Custom formatter: one `String.replace/3` per log event (message size bounded by Logger truncation)

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

**Rollout**: Standard deploy (push to main → GitHub Actions → Coolify). If issues arise, revert the commit and redeploy.

**Rollback**: Revert to previous commit. No data migration needed.

### Documentation updates

- `docs/production-infrastructure.md`: Add "Logging" section under Monitoring & Observability, describing:
  - Logster for HTTP request logging (logfmt format)
  - Custom telemetry handler for LiveView socket connections
  - Custom formatter as single-line safety net
  - Configuration details (formatter module, Logster attach point)
  - Note that dev environment keeps default multi-line format
<!-- SECTION:PLAN:END -->
