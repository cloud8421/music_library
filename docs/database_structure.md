# Database Structure

<!--toc:start-->

- [Database Structure](#database-structure)
  - [Entity Relationship Diagram](#entity-relationship-diagram)
  - [Tables Description](#tables-description)
    - [Records](#records)
    - [Records Search Index](#records-search-index)
    - [Views](#views)
      - [Artist Records View](#artist-records-view)
    - [Triggers](#triggers)
    - [Indices](#indices)
  - [Notes](#notes)
  - [WHY ONE TABLE?](#why-one-table)
  <!--toc:end-->

This document describes the database structure of the Music Library application.

## Entity Relationship Diagram

```mermaid
erDiagram
    RECORDS {
        uuid id PK
        string type
        string format
        string title
        uuid musicbrainz_id
        string[] genres
        string cover_url
        blob cover_data
        string cover_hash
        map musicbrainz_data
        string[] release_ids
        string[] included_release_group_ids
        datetime purchased_at
        string release
        map artists
        datetime inserted_at
        datetime updated_at
    }

    RECORDS_SEARCH_INDEX {
        uuid id PK
        string type
        string format
        string title
        uuid musicbrainz_id
        string[] genres
        string[] release_ids
        string[] included_release_group_ids
        string cover_hash
        datetime purchased_at
        string release
        map artists
    }

    ARTIST_RECORDS {
        uuid musicbrainz_id
        uuid record_id
        map artist
    }

    RECORDS ||--o{ RECORDS_SEARCH_INDEX : "syncs via triggers"
    RECORDS ||--o{ ARTIST_RECORDS : "extracted from artists JSON"
```

## Tables Description

### Records

The main table storing music records. Key features:

- Uses UUID as primary key
- Stores basic record information (title, type, format, year)
- Includes MusicBrainz integration with IDs and additional data
- Stores cover image data and URLs
- Embeds artists data directly in a JSON field
- Includes timestamps for record keeping

### Records Search Index

A virtual FTS5 (Full Text Search) table that mirrors the records table for efficient searching:

- Automatically synced with the records table via triggers
- Optimized for full-text search operations
- Contains most fields from the records table
- Some fields are marked as UNINDEXED for efficiency

### Views

#### Artist Records View

A view that extracts artist information from the embedded JSON in the records table:

```sql
CREATE VIEW artist_records AS
  SELECT json_extract(json_each.value, '$.musicbrainz_id') AS musicbrainz_id,
  records.id AS record_id,
  json_each.value as artist
  FROM records,
  json_each(records.artists)
```

### Triggers

The following triggers maintain the search index:

1. `records_search_index_before_update`: Removes old record data from search index before updates
2. `records_search_index_before_delete`: Removes record data from search index before deletion
3. `records_after_insert`: Inserts new record data into search index after record creation
4. `records_after_update`: Updates record data in search index after record updates

### Indices

The following indices are maintained for performance:

1. On `records`:
   - `format`
   - `title`
   - `musicbrainz_id`
   - `purchased_at`
   - `included_release_group_ids`
   - `release_ids`

## Notes

1. The database uses SQLite as the primary database.
2. Artists data is embedded directly in the records table as JSON/map data, rather than having a separate table.
3. The search index is implemented using SQLite's FTS5 extension for efficient full-text search capabilities.
4. Where needed queries use SQLite's `unicode` extension to filter/sort over UTF-8 data.
5. The database supports both collection and wishlist functionality through the `purchased_at` field:
   - Records with `purchased_at IS NOT NULL` are in the collection
   - Records with `purchased_at IS NULL` are in the wishlist

## WHY ONE TABLE?

In traditional relational database design, you would split out artists into a
separate table, and associate them with records via a join table. So why
sticking with one table?

1. You only need to backup/export one table.
2. Re-fetching data from MusicBrainz becomes trivial, as it just needs to update one field and everything else cascades accordingly.
3. Traditional efficiency design constraints [do not apply to
   SQLite](https://www.sqlite.org/np1queryprob.html), so it makes it easier to experiment with alternative database designs.
