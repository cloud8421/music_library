---
name: production-investigation
description: Use this skill when investigating, triaging, debugging, or responding to production behaviour, production errors, logs, metrics, health, latency, queue activity, crashes, exceptions, stacktraces, ErrorTracker alerts, or application health. Use PROACTIVELY when the user mentions "production", "logs", "metrics", "health", "latency", "slow", "outage", "spike", "error", "production error", "crash", "exception", "stacktrace", "error tracker", "ErrorTracker", "mute", "resolve", "triage", "investigate", "debug production", "what's happening in production", or asks about application health. Also use when fetch_production_errors, fetch_production_logs, or fetch_production_metrics_overview output is available and needs interpretation.
---

# Production Investigation

Systematic workflow for investigating production health, telemetry metrics, logs, and
errors. The project exposes read-only pi tools for production logs, metrics, and
ErrorTracker data, plus explicit mutation tools for muting and resolving understood
errors.

## Guardrails

- Prefer pi production tools over direct infrastructure access.
- Do not SSH into production, use Coolify manually, or change production
  infrastructure unless the user explicitly asks and approves the action.
- Treat `mute`, `unmute`, `resolve`, and `unresolve` as production mutations. Only
  use them when the user asks, or after explaining the impact and getting approval.
- Start broad for unclear health questions, then narrow by symptom, time window,
  category, error reason, or log grep.

## Available Tools

| Tool                                                      | Purpose                                                            | When to Use                                                                                                                    |
| --------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| `fetch_production_metrics_overview`                       | Bounded telemetry overview (`since`, `categories`, `top`)          | First stop for health checks, latency, queue activity, external API issues, database pressure, or unclear production behaviour |
| `fetch_production_errors`                                 | List/filter ErrorTracker errors                                    | Browse unresolved/resolved errors, find noisy or recent exceptions                                                             |
| `fetch_production_error`                                  | Full error details (stacktrace, occurrences, context, breadcrumbs) | Deep-dive into a specific error after listing errors                                                                           |
| `fetch_production_logs`                                   | Recent server logs                                                 | Correlate metrics/errors with request, worker, or infrastructure activity                                                      |
| `mute_production_error` / `unmute_production_error`       | Toggle error notification muting                                   | Silence or re-enable understood error notifications after approval                                                             |
| `resolve_production_error` / `unresolve_production_error` | Toggle error resolution state                                      | Mark fixed errors as resolved, or reopen errors that recur                                                                     |

If additional `fetch_production_metrics_*` tools are available, prefer the most
specific metrics tool for the symptom, and use `fetch_production_metrics_overview`
for the initial bounded summary.

## Investigation Entry Points

### General health or "what's happening in production?"

Start with metrics, then follow the signal:

```
fetch_production_metrics_overview(since: "1h", top: 10)
```

Use `since: "15m"` for acute incidents and `since: "24h"` for trend checks. If the
overview points to errors or a specific subsystem, continue with ErrorTracker or logs.

### Production errors, exceptions, crashes, or alerts

Start with unresolved errors:

```
fetch_production_errors(status: "unresolved", limit: 20)
```

Then fetch the top candidate by ID:

```
fetch_production_error(id: 42)
```

Use metrics to understand blast radius and timing:

```
fetch_production_metrics_overview(since: "1h", categories: "error_tracker,http,oban", top: 10)
```

### Latency, slow pages, or degraded performance

Start with HTTP, Repo, external API, and Oban metrics:

```
fetch_production_metrics_overview(since: "1h", categories: "http,repo,external_api,oban", top: 10)
```

Inspect p95 values first. Use logs only after metrics identify a slow route, worker,
external API, or database symptom worth grepping for.

### Queue, worker, or background-job concerns

Start with Oban metrics and error counters:

```
fetch_production_metrics_overview(since: "1h", categories: "oban,error_tracker", top: 10)
```

Then check logs for the worker name, queue, or error reason if the metrics show slow
execution, retries, discards, or failures.

### Log-specific questions

If the user asks for logs directly, use logs directly and keep the result narrow:

```
fetch_production_logs(grep: "timeout", tail: 50)
```

If logs show a systemic issue, follow up with metrics to quantify frequency and impact.

## Metrics Guidance

`fetch_production_metrics_overview` returns bounded summaries, not raw datapoints.
Use it to find the subsystem and labels that deserve deeper inspection.

| Category        | Look For                                                  | Follow-up                                                                           |
| --------------- | --------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `http`          | High p95 route latency, 5xx/4xx status spikes, hot routes | Check route-specific logs and unresolved errors                                     |
| `repo`          | High query/queue p95, DB contention symptoms              | Look for slow routes/workers; investigate query patterns if code changes are needed |
| `external_api`  | High request p95, failure spikes, rate-limit pressure     | Check API-specific errors/logs and worker retries                                   |
| `oban`          | Slow worker p95, retry/discard spikes, queue hotspots     | Check worker logs, ErrorTracker details, and Oban dashboard if user asks            |
| `error_tracker` | Error count spikes by reason/module                       | Fetch matching unresolved errors and deep-dive by ID                                |
| `vm`            | Memory, scheduler, or runtime pressure                    | Correlate with traffic, worker activity, and logs                                   |

Timing metrics: p95 is usually more useful than averages for user-visible slowness.
Counter metrics: event counts in the selected `since` window are the primary signal.
Metrics can be stale by up to 5 seconds because telemetry storage flushes periodically.

## Error Investigation Workflow

### Step 1: Get an Error Overview

Use narrow filters:

```
fetch_production_errors(status: "unresolved", limit: 20)
```

Note the error IDs, reasons, muted/resolved state, occurrence counts, and recency.

### Step 2: Prioritize

Rank errors by:

1. **Frequency** — errors with many occurrences need attention
2. **Recency** — still happening vs. historical one-off
3. **Impact** — user-facing feature, background job, external API, or bot noise
4. **Metrics correlation** — error counters, HTTP 5xx, slow workers, or latency spikes

### Step 3: Deep Dive on Top Candidates

For each candidate, fetch full details:

```
fetch_production_error(id: 42)
```

Look at:

- **Stacktrace** — which module/function is failing?
- **Occurrences** — pattern over time? Spikes correlate with deployments or cron?
- **Context** — what request params, worker args, or user action triggered it?
- **Breadcrumbs** — what happened before the error?

### Step 4: Correlate with Metrics and Logs

Use metrics to quantify the surrounding symptom:

```
fetch_production_metrics_overview(since: "1h", categories: "error_tracker,http,repo,external_api,oban", top: 10)
```

If the error is infrastructure-related (timeouts, connection issues), check logs with a
specific grep:

```
fetch_production_logs(grep: "timeout", tail: 50)
```

### Step 5: Determine Action

| Finding                                                    | Action                                                                              |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Bot scanner (`NoRouteError`, `wp-admin`, `.env`, `xmlrpc`) | Usually ignored by `ErrorIgnorer`; if still visible, consider adding an ignore rule |
| Expected transient (rate limit, timeout)                   | Monitor metrics/error rate; if spiking, check API health and worker retries         |
| New application bug                                        | Create or update a Backlog task, fix, deploy, and verify with metrics/errors        |
| Recurring non-critical and understood                      | Ask before muting if notification noise is the problem                              |
| Fixed by recent deploy                                     | Verify no new occurrences, then ask before marking resolved                         |

## ErrorIgnorer — What's Already Filtered

`MusicLibrary.ErrorIgnorer` implements `ErrorTracker.Ignorer` and filters non-actionable
errors. These never appear in the error list:

- `NoRouteError` from bot scanners (`wp-admin`, `.env`, `xmlrpc`, etc.)
- Other noise classified as non-actionable

If visible errors look like bot traffic but are not filtered, they may need to be
added to `ErrorIgnorer`.

## ErrorTracker.ErrorNotifier

The notifier is a GenServer that:

- Attaches to ErrorTracker telemetry events
- **Skips muted errors** — no email sent
- **Throttles repeated errors** — does not spam on recurring issues
- **Dispatches email** via `Swoosh.Adapters.Mailgun` when an error meets thresholds

### When to Mute

Mute errors that are:

- **Understood** — you know exactly what causes them
- **Non-actionable** — cannot be fixed, such as sporadic third-party API failures
- **Not impactful** — do not affect user experience
- **Frequent enough to be noisy** — would otherwise spam email

Muted errors still appear in the error list but are filtered by default and do not
trigger email notifications.

### When to Resolve

Mark as resolved when:

- A fix has been deployed and confirmed working
- The error was a one-off that will not recur
- The cause has been eliminated, such as a config change or dependency update

## Common Production Patterns

### External API Failures

```
%Req.TransportError{reason: :timeout}
%Req.TransportError{reason: :econnrefused}
```

→ Check `external_api` p95/failure metrics and error frequency. These are often
transient and Oban workers retry automatically. If spiking, the API may have an outage.

### Rate Limiting

```
%MusicLibrary.LastFm.API.ErrorResponse{kind: :rate_limit}
```

→ Workers snooze and retry. Check `external_api` and `oban` metrics to see whether
rate limiting is isolated or affecting throughput.

### Database Issues

```
%SQLite3.Error{message: "database is locked"}
```

→ Check `repo` query/queue p95 and `oban` worker activity. `heavy_writes` queue has
concurrency 1 to prevent write contention. If happening on `default`, consider moving
the worker.

### OpenAI Quota

```
%OpenAI.API.ErrorResponse{kind: :auth_error, body: %{"code" => "insufficient_quota"}}
```

→ This is a permanent error (`{:cancel, reason}`). Check OpenAI billing/quotas and
related `external_api`/`oban` metrics.

## Post-Fix Verification

After deploying a fix:

1. Check `fetch_production_metrics_overview(since: "15m", ...)` for the affected
   categories to confirm latency/error counters returned to normal.
2. Watch `fetch_production_errors` for new occurrences.
3. Check targeted `fetch_production_logs` output only if metrics or errors still show
   symptoms.
4. Once confirmed resolved, ask before marking the error as resolved.
5. If the fix involved a worker, check Oban activity or logs for cancelled/retried jobs
   related to the error.
