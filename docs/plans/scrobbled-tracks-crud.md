# Scrobbled Tracks Management UI Plan

## Overview

Build a complete UI for managing scrobbled tracks with index, edit, and delete functionality. The interface will be accessible through the "More" menu in the top navigation and will follow existing patterns from collection and wishlist management.

## 1. Database & Context Layer

### Existing Schema

The `LastFm.Track` schema (`lib/last_fm/track.ex`) already exists with:

- Primary key: `scrobbled_at_uts` (Unix timestamp)
- Fields: `musicbrainz_id`, `title`, `cover_url`, `scrobbled_at_label`
- Embedded schemas: `artist` and `album`
- Raw `last_fm_data` map

### Context Functions Needed

Add to `LastFm` module (`lib/last_fm.ex`):

- `list_tracks/1` - Paginated track listing with search support
- `get_track!/1` - Individual track retrieval by `scrobbled_at_uts`
- `update_track/2` - Track metadata updates
- `delete_track/1` - Track deletion
- `search_tracks_count/1` - Count for pagination totals

## 2. LiveView Components

### Index LiveView

**File**: `lib/music_library_web/live/scrobbled_tracks_live/index.ex`

**Pattern**: Follow `CollectionLive.Index` structure

**Features**:

- Paginated list (200 items per page)
- Search functionality by track title/artist name
- Stream-based updates for performance (`phx-update="stream"`)
- Delete confirmation modals
- Edit links to individual track editing

**Default Parameters**:

```elixir
@default_tracks_list_params %{
  query: "",
  page: 1,
  page_size: 200,
  order: :scrobbled_at
}
```

### Edit Form Component

**File**: `lib/music_library_web/live/scrobbled_tracks_live/form_component.ex`

**Pattern**: Follow existing form components (e.g., `ScrobbleRulesLive.FormComponent`)

**Editable Fields**:

- Track title
- Artist name
- Album title
- Scrobbled date/time
- Cover URL (optional)

## 3. Templates & UI Design

### Index Template

**File**: `lib/music_library_web/live/scrobbled_tracks_live/index.html.heex`

**Layout**: Responsive card/list layout similar to collection

**Components**:

- Search bar at top with debounced input
- Track cards displaying:
  - Cover image (with fallback for missing covers)
  - Track title
  - Artist name
  - Album title
  - Scrobbled date/time
  - Edit/Delete action buttons
- Pagination component at bottom using `MusicLibraryWeb.Components.Pagination`
- Empty state message when no tracks found

### Form Component Template

**Features**:

- Form inputs for editable track metadata
- Client-side and server-side validation
- Cancel/Save buttons with proper form handling
- Error display for validation failures

## 4. Routing & Navigation

### Router Updates

**File**: `lib/music_library_web/router.ex`

Add to the logged-in scope around line 65:

```elixir
live "/scrobbled-tracks", ScrobbledTracksLive.Index, :index
live "/scrobbled-tracks/:scrobbled_at_uts/edit", ScrobbledTracksLive.Index, :edit
```

### Navigation Integration

**File**: `lib/music_library_web/components/layouts/app.html.heex`

Add to the "More" dropdown menu (after line 58):

```elixir
<.dropdown_link href={~p"/scrobbled-tracks"}>
  <.icon name="hero-musical-note" class="h-4 w-4 mr-2" aria-hidden="true" data-slot="icon" />
  {gettext("Scrobbled Tracks")}
</.dropdown_link>
```

## 5. Implementation Details

### Pagination Integration

- **Pattern**: Follow `CollectionLive.Index` pagination approach
- **Component**: Reuse `MusicLibraryWeb.Components.Pagination`
- **Parameters**: Support `query`, `page`, `page_size`, and `order`
- **URL Structure**: `/scrobbled-tracks?page=2&query=artist&page_size=50`

### Stream Implementation

- Use `stream(:tracks, tracks)` for efficient rendering of large track lists
- Implement `stream_delete(socket, :tracks, track)` for track deletion
- Handle pagination with `reset: true` for filtered results
- Use unique DOM IDs based on `scrobbled_at_uts`

### Search Functionality

- Search across track title, artist name, and album title
- Use database LIKE queries for basic string matching
- Debounced search input with LiveView `phx-change` events
- Reset to page 1 when search query changes

### Delete Confirmation

- Use modal overlay for delete confirmation
- Show track details (title, artist, date) in confirmation modal
- Implement optimistic UI updates with `stream_delete`
- Handle deletion errors gracefully

### Error Handling

- Validate track existence before edit operations
- Handle database constraint violations
- Display user-friendly error messages
- Graceful fallbacks for missing track data

## 6. File Structure

```
lib/music_library_web/live/scrobbled_tracks_live/
├── index.ex              # Main LiveView controller
├── index.html.heex       # Index template with track listing
└── form_component.ex     # Edit form component

docs/plans/
└── scrobbled-tracks-crud.md  # This plan document
```

## 7. Implementation Steps

1. **Create context functions** in `MusicLibrary.ScrobbleActivity` module for CRUD operations
2. **Implement pagination logic** following existing `CollectionLive.Index` patterns  
3. **Create LiveView** with stream-based track listing and search
4. **Add search functionality** with query parameter handling and debouncing
5. **Implement edit form** with validation and error handling
6. **Add delete functionality** with confirmation modal
7. **Update navigation** to include "Scrobbled Tracks" link in More dropdown
8. **Add routing** for index and edit actions
9. **Style components** using Tailwind CSS and Fluxon UI components
10. **Add comprehensive tests** following existing test patterns

## 8. Technical Considerations

### Primary Key Handling

- Use `scrobbled_at_uts` as unique identifier in routes and database queries
- Handle potential timestamp collisions gracefully
- Consider compound keys if needed for uniqueness

### Performance Optimization

- Use LiveView streams for efficient rendering of large lists
- Implement database indexes on searchable fields
- Paginate results to avoid memory issues
- Use debounced search to reduce database load

### Data Integrity

- Validate required fields (track title, artist name)
- Handle embedded schema updates (artist, album data)
- Preserve Last.fm API data integrity
- Consider soft deletes vs hard deletes

### User Experience

- Consistent styling with existing collection/wishlist pages
- Responsive design for mobile/tablet viewing
- Loading states during pagination and search
- Clear feedback for user actions (edit, delete)
- Accessible keyboard navigation

### Security & Permissions

- Ensure proper authentication via `:logged_in` pipeline
- Validate user permissions for track modifications
- Sanitize input data to prevent XSS
- Use Phoenix CSRF protection

## 9. Testing Strategy

### Unit Tests

- Context function tests for CRUD operations
- LiveView event handling tests
- Form validation tests
- Pagination logic tests

### Integration Tests  

- Full user flow tests (search, edit, delete)
- Navigation integration tests
- Error handling scenarios
- Responsive layout tests

### Test Files

```
test/music_library_web/live/scrobbled_tracks_live_test.exs
test/last_fm_test.exs (extend existing)
test/support/fixtures/scrobbled_tracks_fixtures.ex
```

## 10. Localization

Add gettext entries for:

- Page titles and headings
- Form labels and placeholders
- Error messages
- Action button text
- Empty state messages
- Navigation menu item

## 11. Future Enhancements

### Potential Extensions

- Bulk operations (delete multiple tracks)
- Export functionality (CSV, JSON)
- Advanced filtering (date ranges, specific artists)
- Scrobble statistics and analytics
- Integration with music streaming services
- Track matching with collection records

### Performance Improvements

- Virtual scrolling for very large lists
- Background track synchronization
- Caching for frequently accessed data
- Search index optimization

This plan ensures consistency with existing codebase patterns while providing a complete, user-friendly interface for scrobbled tracks management.

