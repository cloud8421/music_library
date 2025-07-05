# Universal Search Modal Implementation Plan

## Overview

This plan outlines the implementation of a universal search modal that provides unified search across Records (Collection), Records (Wishlist), and Artists. The modal will be accessible via a search icon in the top navigation bar and a keyboard shortcut.

## Requirements

### Core Features
- Modal accessible via:
  - Search icon in top navigation bar
  - Keyboard shortcut (Ctrl/Cmd + K)
- Search across three entity types:
  1. Records in Collection
  2. Records in Wishlist  
  3. Artists
- Real-time search as user types
- Keyboard navigation support
- Mobile-responsive design

### Search Functionality
- Leverage existing FTS5 search infrastructure
- Support existing search syntax (artist:, album:, genre:, etc.)
- Show search results grouped by entity type
- Limit results per category (e.g., 5 per type)
- Click-to-navigate to full results or individual records

## Technical Architecture

### 1. Modal Component Structure

**New Components:**
- `UniversalSearchModal` - Main modal component
- `SearchResultGroup` - Groups results by type (Collection, Wishlist, Artists)
- `SearchResultItem` - Individual result display
- `SearchInput` - Enhanced search input with keyboard shortcuts

**Component Location:**
```
lib/music_library_web/components/
├── search_components.ex          # New universal search components
└── layouts/app.html.heex         # Add search icon to navigation
```

### 2. LiveView Integration

**New LiveView Module:**
```
lib/music_library_web/live/universal_search_live/
├── index.ex                      # Main search LiveView
└── index.html.heex              # Search modal template
```

**Integration Points:**
- Mount as child LiveView in main layout
- Handle modal open/close state
- Manage search query and results
- Handle keyboard navigation

### 3. Backend Search Implementation

**New Context Functions:**
```elixir
# In lib/music_library/search.ex (new module)
def universal_search(query, opts \\ [])
def search_collection(query, limit \\ 5)
def search_wishlist(query, limit \\ 5) 
def search_artists(query, limit \\ 5)
```

**Search Strategy:**
- Reuse existing `Records.search_collection/2` and `Records.search_wishlist/2`
- Extend `Artists.search/2` or create new artist search function
- Combine results with type metadata
- Implement result limiting and pagination

### 4. Database Considerations

**Leverage Existing Infrastructure:**
- Use existing `records_search_index` FTS5 table
- Utilize existing search parser for tagged queries
- Consider artist search optimization (may need artist search index)

**Artist Search Enhancement:**
- Current artist search may need optimization
- Consider adding FTS5 index for artist_infos table if performance issues
- Leverage existing artist_records view for artist-record relationships

## Implementation Details

### 1. Modal Behavior

**Desktop:**
- Modal opens centered on screen
- Size: `max-w-2xl` (responsive)
- Overlay with backdrop blur
- Esc key to close, click outside to close

**Mobile:**
- Full-screen modal on mobile (`sm:max-w-2xl max-w-full`)
- Touch-friendly result items
- Swipe down to close (if feasible)
- Virtual keyboard considerations

### 2. Search Interface

**Search Input:**
- Placeholder: "Search records and artists..."
- Auto-focus when modal opens
- Debounced search (300ms delay)
- Clear button when text present
- Loading indicator during search

**Search Results:**
```
┌─────────────────────────────────────┐
│ Search: "radiohead ok computer"     │
├─────────────────────────────────────┤
│ COLLECTION (3 results)              │
│ • OK Computer - Radiohead           │
│ • Kid A - Radiohead                 │
│ • In Rainbows - Radiohead           │
│ View all 12 collection results →    │
├─────────────────────────────────────┤
│ WISHLIST (1 result)                 │
│ • Hail to the Thief - Radiohead     │
│ View all 1 wishlist results →       │
├─────────────────────────────────────┤
│ ARTISTS (1 result)                  │
│ • Radiohead                         │
│ View artist page →                  │
└─────────────────────────────────────┘
```

### 3. Keyboard Navigation

**Keyboard Shortcuts:**
- `Ctrl/Cmd + K` - Open modal
- `Esc` - Close modal
- `↑/↓` - Navigate results
- `Enter` - Select highlighted result
- `Tab` - Move between sections

**Implementation:**
- Use Phoenix LiveView's `phx-window-keydown` for global shortcuts
- Implement focus management with JavaScript hooks
- Maintain accessibility standards (ARIA labels, focus indicators)

### 4. Result Navigation

**Click Actions:**
- Record results → Navigate to record show page
- Artist results → Navigate to artist page
- "View all X results" → Navigate to respective list page with search applied

**URL Strategy:**
- Don't change URL for modal open/close
- When navigating to results, apply search query to destination page
- Use existing search parameter patterns

## Database Schema Impact

**No Schema Changes Required:**
- Leverage existing tables and search infrastructure
- May add database indexes for performance if needed

**Performance Considerations:**
- Monitor query performance with combined searches
- Consider query result caching for common searches
- Implement search result limits to prevent slow queries

## Testing Strategy

### 1. Unit Tests

**Search Logic Tests:**
```elixir
# test/music_library/search_test.exs
describe "universal_search/2" do
  test "searches across all entity types"
  test "limits results per category"
  test "handles empty queries"
  test "handles special characters"
  test "respects search syntax (artist:, album:, etc.)"
end
```

### 2. Integration Tests

**LiveView Tests:**
```elixir
# test/music_library_web/live/universal_search_live_test.exs
describe "UniversalSearchLive" do
  test "opens modal on keyboard shortcut"
  test "searches as user types"
  test "displays results grouped by type"
  test "navigates to selected results"
  test "handles keyboard navigation"
  test "closes modal on escape"
end
```

### 3. Component Tests

**Search Components:**
```elixir
# test/music_library_web/components/search_components_test.exs
describe "SearchResultGroup" do
  test "renders results with proper grouping"
  test "shows 'view all' link when more results available"
  test "handles empty result sets"
end
```

### 4. JavaScript/Hook Tests

**Browser Tests:**
- Test keyboard shortcuts work globally
- Test focus management
- Test modal open/close behavior
- Test mobile touch interactions

## Mobile Considerations

### 1. Layout Adaptations

**Mobile Modal:**
- Full-screen on small devices
- Reduced padding and margins
- Larger touch targets for results
- Simplified result display (fewer details)

**Touch Interactions:**
- Swipe down to close modal
- Tap to select results
- Pull-to-refresh for search results

### 2. Performance

**Mobile Optimization:**
- Shorter debounce delays on mobile
- Reduced result limits on mobile
- Lazy loading for large result sets
- Optimize image loading for album covers

### 3. Virtual Keyboard

**iOS/Android Considerations:**
- Modal positioning with virtual keyboard
- Proper input focus management
- Prevent zoom on input focus

## Implementation Phases

### Phase 1: Core Modal Infrastructure
1. Create basic modal component
2. Add search icon to navigation
3. Implement modal open/close
4. Add keyboard shortcut support

### Phase 2: Search Backend
1. Create universal search context
2. Implement combined search functions
3. Add result limiting and grouping
4. Optimize query performance

### Phase 3: Search Interface
1. Implement search input with debouncing
2. Add search result display
3. Implement keyboard navigation
4. Add result selection and navigation

### Phase 4: Mobile & Polish
1. Mobile layout optimizations
2. Touch interaction improvements
3. Performance optimizations
4. Accessibility enhancements

### Phase 5: Testing & Documentation
1. Comprehensive test coverage
2. Performance testing
3. Mobile device testing
4. Documentation updates

## Success Metrics

**Functionality:**
- Modal opens/closes reliably
- Search results are accurate and fast
- Keyboard navigation works smoothly
- Mobile experience is touch-friendly

**Performance:**
- Search queries complete in <500ms
- Modal opens in <100ms
- No janky animations or interactions
- Efficient database queries

**Usability:**
- Easy to discover and use
- Intuitive keyboard shortcuts
- Clear result presentation
- Seamless navigation to results

## Risks and Mitigation

**Performance Risks:**
- Complex queries may be slow
- **Mitigation:** Implement query limits, caching, and monitoring

**Mobile Experience:**
- Small screen constraints
- **Mitigation:** Responsive design, touch-friendly interfaces

**Accessibility:**
- Keyboard navigation complexity
- **Mitigation:** Follow ARIA guidelines, comprehensive testing

**Search Accuracy:**
- Users may expect Google-like search
- **Mitigation:** Clear documentation of search syntax, good defaults

## Future Enhancements

**Advanced Features:**
- Search history and suggestions
- Saved searches
- Search filters and facets
- Search result previews

**Integration:**
- Integration with barcode scanning
- Voice search capabilities
- External search (MusicBrainz, Last.fm)

**Analytics:**
- Search usage analytics
- Popular search terms
- Search success rates

## Conclusion

This universal search modal will significantly improve the user experience by providing quick access to all content types from any page. The implementation leverages existing infrastructure while adding a modern, accessible search interface that works well on both desktop and mobile devices.

The phased approach ensures a solid foundation while allowing for iterative improvements based on user feedback and usage patterns.