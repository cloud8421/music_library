---
name: error-investigation
description: Use this skill when investigating, triaging, debugging, or responding to production errors. Use PROACTIVELY when the user mentions "error", "production error", "crash", "exception", "stacktrace", "error tracker", "ErrorTracker", "mute", "resolve", "triage", "investigate", "debug production", "what's happening in production", or asks about application health. Also use when fetch_production_errors or fetch_production_logs output is available and needs interpretation.
---

# Error Investigation

Systematic workflow for investigating and triaging production errors. The project
uses ErrorTracker with email notifications, mute support, and an ignorer for
non-actionable errors.

## Available Tools

| Tool | Purpose | When to Use |
|------|---------|------------|
| `fetch_production_errors` | List/filter errors | Starting point — browse recent errors |
| `fetch_production_error` | Full error details (stacktrace, occurrences, context) | Deep-dive into a specific error |
| `fetch_production_logs` | Recent server logs | Correlate errors with server activity |

## Investigation Workflow

### Step 1: Get an Overview

Start with `fetch_production_errors` with narrow filters:

```
fetch_production_errors(status: "unresolved", limit: 20)
```

Note the error IDs, reasons, and occurrence counts.

### Step 2: Prioritize

Rank errors by:

1. **Frequency** — errors with hundreds of occurrences need attention
2. **Recency** — is it still happening or was it a one-off?
3. **Impact** — does it affect user-facing features or is it background noise?

### Step 3: Deep Dive on Top Candidates

For each candidate, fetch full details:

```
fetch_production_error(id: 42)
```

Look at:
- **Stacktrace** — which module/function is failing?
- **Occurrences** — pattern over time? Spikes correlate with deployments?
- **Context** — what request params or user action triggered it?
- **Breadcrumbs** — what happened before the error?

### Step 4: Correlate with Logs

If the error is infrastructure-related (timeouts, connection issues), check logs:

```
fetch_production_logs(grep: "timeout", tail: 50)
```

### Step 5: Determine Action

| Error Type | Action |
|-----------|--------|
| Bot scanner (NoRouteError, wp-admin, .env, xmlrpc) | Already ignored by `ErrorIgnorer` — nothing to do |
| Expected transient (rate limit, timeout) | Monitor occurrence rate; if spiking, check API health |
| New bug | Create Backlog task, fix, deploy |
| Recurring non-critical | Mute if understood and not actionable |
| Resolved by recent deploy | Mark as resolved |

## ErrorIgnorer — What's Already Filtered

`MusicLibrary.ErrorIgnorer` implements `ErrorTracker.Ignorer` and filters non-actionable
errors. These never appear in the error list:

- `NoRouteError` from bot scanners (wp-admin, .env, xmlrpc, etc.)
- Other noise classified as non-actionable

If you see errors that look like bot traffic but aren't filtered, they may need to
be added to `ErrorIgnorer`.

## ErrorTracker.ErrorNotifier

The notifier is a GenServer that:
- Attaches to ErrorTracker telemetry events
- **Skips muted errors** — no email sent
- **Throttles repeated errors** — doesn't spam on recurring issues
- **Dispatches email** via `Swoosh.Adapters.Mailgun` when an error meets thresholds

### When to Mute

Mute errors that are:
- **Understood** — you know exactly what causes it
- **Non-actionable** — can't fix (e.g., third-party API sporadic failures)
- **Not impactful** — doesn't affect user experience
- **Frequent enough to be noisy** — would otherwise spam email

Muted errors still appear in the error list but are filtered by default and don't
trigger email notifications.

### When to Resolve

Mark as resolved when:
- A fix has been deployed and confirmed working
- The error was a one-off that won't recur
- The cause has been eliminated (e.g., config change, dependency update)

## Common Error Patterns

### External API Failures

```
%Req.TransportError{reason: :timeout}
%Req.TransportError{reason: :econnrefused}
```

→ Check if the API is down. These are transient and Oban workers retry automatically.
Monitor frequency — if spiking, the API may have an outage.

### Rate Limiting

```
%MusicLibrary.LastFm.API.ErrorResponse{kind: :rate_limit}
```

→ Workers snooze and retry. Check if rate limit intervals need adjustment.

### Database Issues

```
%SQLite3.Error{message: "database is locked"}
```

→ Check for concurrent write contention. `heavy_writes` queue has concurrency 1 to
prevent this. If happening on `default` queue, consider moving the worker.

### OpenAI Quota

```
%OpenAI.API.ErrorResponse{kind: :auth_error, body: %{"code" => "insufficient_quota"}}
```

→ This is a permanent error (`{:cancel, reason}`). Check OpenAI billing/quotas.

## Post-Fix Verification

After deploying a fix:
1. Watch `fetch_production_errors` for new occurrences
2. Once confirmed resolved, mark the error as resolved
3. If the fix involved a worker, check Oban Web for any cancelled jobs related to
   the error
