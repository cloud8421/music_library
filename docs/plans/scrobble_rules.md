# Scrobbled Tracks Data Transformation Rules - Implementation Plan

## Overview

This plan outlines the implementation of functionality to manage arbitrary rules for fixing data in the `scrobbled_tracks` table. The system will support two types of transformations:

1. **Album Rule**: Update the album MusicBrainz ID of all tracks belonging to a specific album (identified by album title)
2. **Artist Rule**: Update the artist MusicBrainz ID of all tracks belonging to a specific artist (identified by artist name)

## Current State Analysis

### Existing Database Schema

- `scrobbled_tracks` table exists with the following structure:
  - `scrobbled_at_uts` (integer, primary key)
  - `musicbrainz_id` (string) - track MusicBrainz ID
  - `title` (string) - track title
  - `cover_url` (string)
  - `scrobbled_at_label` (string)
  - `artist` (map) - embedded artist data with `musicbrainz_id` and `name`
  - `album` (map) - embedded album data with `musicbrainz_id` and `title`
  - `last_fm_data` (map) - raw Last.fm API response

### Existing Schemas

- `LastFm.Track` - Schema for scrobbled tracks
- `LastFm.Artist` - Embedded artist schema
- `LastFm.Album` - Embedded album schema

### Navigation Structure

- Main navigation has Stats, Collection, Wishlist sections
- "More" dropdown contains development tools and utilities
- Uses Phoenix LiveView for interactive components

## Implementation Plan

### 1. Database Migration

**File**: `priv/repo/migrations/YYYYMMDDHHMMSS_create_scrobble_rules.exs`

Create `scrobble_rules` table with:

- `id` (primary key)
- `type` (string) - "album" or "artist"
- `match_value` (string) - album title or artist name to match
- `target_musicbrainz_id` (string) - MusicBrainz ID to set
- `enabled` (boolean) - whether rule is active
- `description` (text) - optional description for the rule
- `inserted_at` (timestamp)
- `updated_at` (timestamp)

Indexes:

- `type, match_value` (compound index for efficient matching)
- `enabled` (for filtering active rules)

### 2. Schema Module

**File**: `lib/music_library/scrobble_rules/scrobble_rule.ex`

Create Ecto schema with:

- Field definitions matching migration
- Validations:
  - `type` must be "album" or "artist"
  - `match_value` required and non-empty
  - `target_musicbrainz_id` required and non-empty
  - `enabled` defaults to true
- Changeset functions for create/update operations

### 3. Context Module

**File**: `lib/music_library/scrobble_rules.ex`

Implement context functions:

- `list_scrobble_rules(opts \\ [])` - list all rules with optional filtering
- `get_scrobble_rule!(id)` - get specific rule by ID
- `create_scrobble_rule(attrs)` - create new rule
- `update_scrobble_rule(rule, attrs)` - update existing rule
- `delete_scrobble_rule(rule)` - delete rule
- `change_scrobble_rule(rule, attrs \\ %{})` - create changeset
- `list_enabled_rules()` - get only enabled rules for worker
- `apply_album_rule(rule)` - apply album transformation
- `apply_artist_rule(rule)` - apply artist transformation
- `apply_all_rules()` - apply all enabled rules

### 4. Navigation Update

**File**: `lib/music_library_web/components/layouts/app.html.heex`

Add new navigation link in the "More" dropdown:

- Icon: `hero-adjustments-horizontal`
- Label: "Scrobble Rules"
- Route: `/scrobble-rules`
- Position: After "Oban" link, before separator

### 5. Router Configuration

**File**: `lib/music_library_web/router.ex`

Add new LiveView routes in the authenticated scope:

- `/scrobble-rules` - index page
- `/scrobble-rules/new` - create new rule
- `/scrobble-rules/:id/edit` - edit existing rule

### 6. LiveView Implementation

**File**: `lib/music_library_web/live/scrobble_rules_live/index.ex`

Implement LiveView with:

- List view showing all rules with status indicators
- Create/Edit forms with validation
- Delete confirmation
- Filter controls (by type, enabled/disabled)
- Manual rule application triggers
- Real-time updates via PubSub

**Template**: `lib/music_library_web/live/scrobble_rules_live/index.html.heex`

- Table layout with rule details
- Action buttons (Edit, Delete, Apply)
- Form components for create/edit
- Status indicators for enabled/disabled rules

### 7. Form Components

**File**: `lib/music_library_web/live/scrobble_rules_live/form_component.ex`

Create reusable form component:

- Type selection (album/artist)
- Match value input with validation
- Target MusicBrainz ID input
- Description textarea
- Enable/disable toggle
- Save/Cancel actions

Where possible, use the components available at <https://docs.fluxonui.com/1.1.4/overview.html>.

### 8. Periodic Worker

**File**: `lib/music_library/scrobble_rules/worker.ex`

Implement Oban worker:

- Scheduled to run periodically (e.g., every 30 minutes)
- Fetches all enabled rules
- Applies each rule in sequence
- Logs application results
- Handles errors gracefully
- Tracks last application time

### 9. Testing Strategy

#### Unit Tests

**File**: `test/music_library/scrobble_rules_test.exs`

- Test all context functions
- Test rule application logic
- Test edge cases and error handling

**File**: `test/music_library/scrobble_rules/scrobble_rule_test.exs`

- Test schema validations
- Test changeset functions
- Test constraint validations

#### Integration Tests

**File**: `test/music_library_web/live/scrobble_rules_live_test.exs`

- Test LiveView interactions
- Test form submissions
- Test real-time updates
- Test navigation and routing

#### Worker Tests

**File**: `test/music_library/scrobble_rules/worker_test.exs`

- Test job execution
- Test rule application
- Test error handling
- Test scheduling

### 11. Additional Considerations

#### Data Integrity

- Ensure atomic operations when applying rules
- Validate MusicBrainz IDs before applying
- Log all transformations for audit trail

#### Performance

- Index optimization for rule matching
- Batch processing for large datasets
- Rate limiting for external API calls

#### User Experience

- Clear feedback on rule application
- Preview mode to show what would change
- Bulk operations for managing multiple rules
- Export/import functionality for rule sets

#### Security

- Input validation and sanitization
- Rate limiting on rule creation
- Audit logging for all changes

## Database Schema Summary

```sql
-- scrobble_rules table
CREATE TABLE scrobble_rules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL CHECK (type IN ('album', 'artist')),
  match_value TEXT NOT NULL,
  target_musicbrainz_id TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  description TEXT,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_scrobble_rules_type_match ON scrobble_rules(type, match_value);
CREATE INDEX idx_scrobble_rules_enabled ON scrobble_rules(enabled);
```

## File Structure Summary

```
lib/music_library/
├── scrobble_rules/
│   ├── scrobble_rule.ex          # Schema
│   └── worker.ex                 # Oban worker
└── scrobble_rules.ex             # Context

lib/music_library_web/
└── live/
    └── scrobble_rules_live/
        ├── index.ex              # LiveView
        ├── index.html.heex       # Template
        └── form_component.ex     # Form component

priv/repo/migrations/
└── YYYYMMDDHHMMSS_create_scrobble_rules.exs

test/
├── music_library/
│   ├── scrobble_rules_test.exs
│   └── scrobble_rules/
│       ├── scrobble_rule_test.exs
│       └── worker_test.exs
└── music_library_web/
    └── live/
        └── scrobble_rules_live_test.exs
```

## Implementation Order

1. Database migration and schema
2. Context module with basic CRUD operations
3. LiveView interface for rule management
4. Navigation and routing updates
5. Periodic worker implementation
6. Comprehensive testing
7. Documentation and deployment

This plan ensures a robust, maintainable solution that integrates seamlessly with the existing Music Library application architecture.

