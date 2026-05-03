---
id: doc-3
title: 'Research: Force production logs to single-line format'
type: other
created_date: '2026-05-03 13:53'
updated_date: '2026-05-03 14:23'
---
# Research: Force production logs to single-line format

## Current state

**Config** (`config/config.exs`):
```elixir
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]
```

**Override** (`config/prod.exs`):
```elixir
config :logger, level: :info
```

**Log sources in prod**:

| Source | Produces | Problem |
|---|---|---|
| `Phoenix.Logger` (telemetry) | `GET /health` + `Sent 200 in Xms` | Two separate lines for one request — can't reverse |
| `Phoenix.Logger` (telemetry) | `CONNECTED TO Phoenix.LiveView.Socket...` | One event with embedded `\n` — 4+ lines |
| Custom `Logger.info/error/...` | Varies | Some may be multi-line |
| OTP / stack traces | Crash reports | Multi-line |

`Phoenix.Logger` is auto-attached by Phoenix.Endpoint and handles telemetry events including `[:phoenix, :endpoint, :start]`, `[:phoenix, :endpoint, :stop]`, and `[:phoenix, :socket_connected]`.

## Chosen approach: Option 2 (comprehensive)

1. **Disable Phoenix.Logger** — `config :phoenix, :logger, false` in prod
2. **Add Logster v2** — `Logster.attach_phoenix_logger()` for single-line HTTP request logging (logfmt format)
3. **Custom telemetry handler** — for `[:phoenix, :socket_connected]` LiveView handshakes (if not covered by Logster)
4. **Custom Logger.Formatter** — safety net replacing `\n` → `\\n` in all remaining messages
5. **Code audit** — fix multi-line Logger calls in project code

### Why Logster v2 over v1

v2 (`~> 2.0.0-rc.5`) uses `Logster.attach_phoenix_logger()` in `application.ex` instead of replacing a plug in the endpoint. This is the modern approach that works with Phoenix's telemetry-based logging architecture. It outputs logfmt (`key=value`) format by default, merging the `GET /path` and `Sent 200` lines into one.

### Architecture impact

| Touchpoint | Change |
|---|---|
| `config/prod.exs` | Add `config :phoenix, :logger, false` + Logster config + formatter config |
| `lib/music_library/application.ex` | Add conditional `Logster.attach_phoenix_logger()` |
| `lib/music_library_web/telemetry_log_handler.ex` | **New module** — handles socket_connected telemetry |
| `lib/music_library/logger/single_line_formatter.ex` | **New module** — Logger.Formatter format function |
| `mix.exs` | Add `{:logster, "~> 2.0.0-rc.5"}` |
| Docs | Update `docs/production-infrastructure.md` with logging config |

### Performance

- Logster: one telemetry handler invocation per request, logfmt formatting is string interpolation — negligible overhead
- Custom formatter: one `String.replace/3` per log event, Logger already truncates messages — negligible
- No CPU or memory concerns at the log volume of a personal app

### Dependencies

- `logster ~> 2.0.0-rc.5` (1.9M downloads, MIT license, active maintenance)

### Cost

- None — no paid services involved

---

## Questions resolved

1. **Newline style**: Replace `\n` with `\\n` (escaped, traceable)
2. **Scope**: Prod-only; dev keeps current multi-line format for readability
3. **Module naming**: `MusicLibrary.Logger.SingleLineFormatter` and `MusicLibraryWeb.TelemetryLogHandler`
