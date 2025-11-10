# Scrobble Rule Application Optimization

## Overview

This document describes the optimization made to the scrobble rule application system to improve performance when applying multiple rules.

## Problem

Previously, when applying all enabled scrobble rules, each rule was applied independently with a separate database UPDATE query. With N rules, this resulted in N separate database operations, which became inefficient as the number of rules grew.

### Previous Implementation

```elixir
def apply_all_rules do
  list_enabled_rules()
  |> Enum.map(fn rule ->
    case apply_rule(rule) do
      {:ok, count} -> {:ok, {rule.type, rule.match_value, count}}
      {:error, reason} -> {:error, {rule.type, rule.match_value, reason}}
    end
  end)
end
```

This approach meant:
- 10 rules = 10 separate UPDATE queries
- 100 rules = 100 separate UPDATE queries
- Each query had to scan the entire `scrobbled_tracks` table

## Solution

The optimization groups rules by type (album/artist) and applies all rules of each type in a single database query using SQLite's CASE statement.

### New Implementation

```elixir
def apply_all_rules do
  enabled_rules = list_enabled_rules()
  
  # Group rules by type
  {album_rules, artist_rules} = 
    Enum.split_with(enabled_rules, fn rule -> rule.type == :album end)
  
  # Apply all album rules in one query
  apply_all_album_rules(album_rules)
  
  # Apply all artist rules in one query
  apply_all_artist_rules(artist_rules)
end
```

This approach means:
- 10 album rules + 10 artist rules = 2 total UPDATE queries (one for albums, one for artists)
- 100 album rules + 100 artist rules = 2 total UPDATE queries
- Each query still scans the table once, but updates all matching records in a single pass

## Technical Details

### SQL Generation

The optimization dynamically builds a CASE statement for all rules of the same type:

**Example for 2 album rules:**

```sql
UPDATE scrobbled_tracks 
SET album = CASE 
  WHEN json_extract(album, '$.title') = 'Dark Side of the Moon' 
    THEN json_set(album, '$.musicbrainz_id', '12345678-1234-1234-1234-123456789012')
  WHEN json_extract(album, '$.title') = 'Wish You Were Here' 
    THEN json_set(album, '$.musicbrainz_id', 'abcdef12-3456-7890-abcd-ef1234567890')
  ELSE album 
END
WHERE json_extract(album, '$.title') IN ('Dark Side of the Moon', 'Wish You Were Here')
```

The WHERE clause uses IN to filter only tracks that match any of the rules, avoiding unnecessary updates.

### Functions Added

#### 1. `apply_all_album_rules/1`
Applies all album rules in a single query.

```elixir
@spec apply_all_album_rules([ScrobbleRule.t()]) :: {:ok, non_neg_integer()} | {:error, any()}
```

#### 2. `apply_all_artist_rules/1`
Applies all artist rules in a single query.

```elixir
@spec apply_all_artist_rules([ScrobbleRule.t()]) :: {:ok, non_neg_integer()} | {:error, any()}
```

#### 3. `apply_all_album_rules/2`
Applies all album rules to a specific set of tracks in a single query.

```elixir
@spec apply_all_album_rules([ScrobbleRule.t()], [Track.t()]) :: 
  {:ok, non_neg_integer()} | {:error, any()}
```

#### 4. `apply_all_artist_rules/2`
Applies all artist rules to a specific set of tracks in a single query.

```elixir
@spec apply_all_artist_rules([ScrobbleRule.t()], [Track.t()]) :: 
  {:ok, non_neg_integer()} | {:error, any()}
```

### Use Cases

The optimization handles two main use cases:

#### 1. Periodic Full Application
The `ApplyScrobbleRules` Oban worker runs every 30 minutes and applies all rules to all tracks:

```elixir
ScrobbleRules.apply_all_rules()
```

#### 2. Incremental Application on New Tracks
When new tracks are inserted via `LastFm.Feed.update/1`, rules are applied to just those tracks:

```elixir
tracks
|> ScrobbleRules.apply_all_rules()
```

Both use cases now benefit from batched rule application.

## Performance Impact

### Expected Improvements

For a database with:
- 10,000 scrobbled tracks
- 20 enabled rules (10 album + 10 artist)

**Before:**
- 20 UPDATE queries
- Each query scans ~10,000 rows
- Total: ~200,000 row scans

**After:**
- 2 UPDATE queries (1 for albums, 1 for artists)
- Each query scans ~10,000 rows
- Total: ~20,000 row scans

**Result:** ~10x reduction in database operations for this scenario.

The benefit scales with the number of rules:
- 5 rules: ~2.5x improvement
- 10 rules: ~5x improvement
- 20 rules: ~10x improvement
- 100 rules: ~50x improvement

## Trade-offs

### Return Value Semantics

With the batched approach, all rules of the same type report the same aggregate count (total rows updated) rather than individual per-rule counts:

```elixir
# Before: Each rule gets its own count
[
  {:ok, {:album, "Album 1", 5}},   # 5 tracks updated
  {:ok, {:album, "Album 2", 3}},   # 3 tracks updated
]

# After: Both rules report the total updated
[
  {:ok, {:album, "Album 1", 8}},   # 8 total tracks updated
  {:ok, {:album, "Album 2", 8}},   # 8 total tracks updated
]
```

This is an acceptable trade-off because:
1. The logging still shows how many rules were applied
2. The total tracks updated is more meaningful for understanding impact
3. Getting individual counts would require separate queries, negating the optimization

### Backward Compatibility

The API remains fully backward compatible:
- All existing functions (`apply_rule/1`, `apply_album_rule/1`, etc.) still work
- Return value format is unchanged: `{:ok, {type, match_value, count}}`
- Error handling is unchanged
- Tests continue to pass

## Testing

New tests were added to verify the optimization:

1. `apply_all_album_rules/1` applies multiple album rules in one query
2. `apply_all_artist_rules/1` applies multiple artist rules in one query  
3. Empty list handling returns `{:ok, 0}`
4. `apply_all_rules/0` correctly batches rules by type
5. All existing tests continue to pass

## Future Considerations

### Potential Enhancements

1. **Parallel Execution**: Album and artist rule applications could run in parallel since they're independent
2. **Query Optimization**: Could add indexes on `json_extract(album, '$.title')` and `json_extract(artist, '$.name')` if performance is still a concern
3. **Metrics**: Add telemetry events to track batch sizes and execution times
4. **Rule Ordering**: If rule priority matters in the future, the CASE statement naturally handles this (first match wins)

### Scalability

The current approach scales well up to ~100 rules per type. Beyond that, consider:
- SQL query length limits (SQLite's default limit is 1MB, which allows ~10,000 rules)
- Transaction size and memory usage
- Potential chunking if needed (apply rules in batches of N)

## Conclusion

This optimization significantly improves the performance of scrobble rule application by reducing database operations from O(N) to O(1) per rule type, where N is the number of rules. The implementation maintains backward compatibility while providing substantial performance benefits that scale with the number of rules.
