---
name: query-reporter
description: Capture Ecto SQL queries to a log file for analysis. Use this skill when the user asks to trace, capture, log, or inspect database queries, or mentions "SQL log", "query trace", "query capture", "what queries does this page run". Also use proactively when investigating slow pages, debugging N+1 queries, analyzing database performance, or when you need to understand what SQL a LiveView or action produces. Requires a running Phoenix server with Tidewave MCP.
model: haiku
context: fork
---

# Query Reporter

Captures all Ecto queries executed by the main Repo to a log file as executable
SQL with interpolated parameters and source location comments.

## Before You Start

This skill requires the Tidewave MCP tools. Before proceeding, check whether
`mcp__tidewave__project_eval` is available in your tool list.

If Tidewave is not available, stop and tell the user:
"The query reporter requires a running Phoenix server with Tidewave. Please start
the server with `mise run dev:console` and ensure Tidewave is loaded, then try again."

## Workflow

### 1. Start capturing

Pick a file path (use `/tmp/` to avoid cluttering the project):

```elixir
mcp__tidewave__project_eval(code: ~s[MusicLibrary.QueryReporter.start("/tmp/queries.sql")])
```

This truncates the file if it exists. Calling `start/1` again restarts with a fresh file.

### 2. Trigger the queries you want to capture

Navigate to a page, click a button, run a context function — whatever action you want
to trace. Use Chrome DevTools MCP tools to visit pages if needed.

### 3. Stop capturing

```elixir
mcp__tidewave__project_eval(code: ~s[MusicLibrary.QueryReporter.stop()])
```

### 4. Read the log

Read the file you specified in step 1 to see all captured queries.

## Output Format

Each query in the log file looks like:

```sql
-- MusicLibrary.Collection.list_records/2, at: lib/music_library/collection.ex:42
-- total=2.6ms db=2.6ms queue=0.0ms decode=0.0ms
SELECT r0."id", r0."title" FROM "records" AS r0 WHERE (r0."purchased_at" IS NOT NULL) LIMIT 20;
```

- The first comment shows the Elixir function and file:line that originated the query
- The second comment shows timing: total, db (query execution), queue (connection wait), decode
- Parameters are fully interpolated (no `?` placeholders)
- Each query ends with `;` and is separated by a blank line
- Queries are executable — you can paste them into `sqlite3` or `mcp__tidewave__execute_sql_query`

## What Gets Captured

- All queries through `MusicLibrary.Repo` (the main application database)
- Includes SELECT, INSERT, UPDATE, DELETE, and transaction statements (BEGIN/COMMIT)
- Does **not** capture BackgroundRepo (Oban) or TelemetryRepo queries

## Tips

- The reporter adds minimal overhead (one file append per query), but remember to
  stop it when you're done to avoid filling the log with unrelated queries
- LiveView pages fire queries twice on initial load (once for the static mount,
  once for the connected mount) — this is normal Phoenix behaviour
- To capture queries from a specific action, start the reporter, perform only that
  action, then stop immediately
