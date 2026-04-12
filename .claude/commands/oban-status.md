Query the Oban job queue status using Tidewave's `execute_sql_query` tool against the `MusicLibrary.BackgroundRepo`.

Run this SQL query:

```sql
SELECT state, worker, count(*) as count
FROM oban_jobs
GROUP BY state, worker
ORDER BY state, count DESC
```

Present the results as a formatted table grouped by state. If there are failed or retryable jobs, show their error details.
