# Record Management

- Import a record from a MusicBrainz release ID
- Import a record from a MusicBrainz release group
- Search records with filtering and pagination
- Get random record from collection
- Get latest purchased record
- Refresh record metadata from MusicBrainz
- Generate genres for a record using AI
- Update cover art from MusicBrainz
- Extract dominant colors from album artwork
- Create, update, or delete records
- Resize cover art to standard dimensions

# Collection Operations

- Add record to collection (mark as purchased)
- Search collection with various filters
- View collection statistics by format (CD, vinyl, etc.)
- View collection statistics by type (album, EP, etc.)
- Get top artists in collection by record count
- Get top genres in collection by record count

# Wishlist Operations

- Add record to wishlist
- Search wishlist records
- Count total wishlist items
- Check which releases are wishlisted

# Last.fm Integration

- Scrobble a release to Last.fm
- Scrobble a specific disc/medium to Last.fm
- Import listening history from Last.fm
- Get top albums by time period (7/30/90/365 days)
- Get top artists by time period
- Get most recent scrobbled track for a record
- Backfill historical Last.fm data
- Refresh scrobbled tracks from Last.fm
- Get Last.fm authentication session

# Search Operations

- Universal search across collection, wishlist, and artists
- Search collection records
- Search wishlist records
- Search artists by name
- Search records by barcode

# Artist Management

- Fetch artist information from MusicBrainz and Discogs
- Get similar artists from Last.fm that are in collection
- Download and cache artist images
- View artist's records in collection
- Clean up unused artist information

# Data Quality & Rules

- Create scrobble correction rules for album names
- Create scrobble correction rules for artist names
- Apply correction rules to scrobbled tracks
- Count tracks affected by correction rules
- Enable/disable correction rules

# Barcode Scanning

- Scan barcode and check collection/wishlist status
- Import multiple scanned records in batch
- Import single scanned record from barcode

# External Store Integration

- Create templates for online music stores
- Generate purchase URLs from store templates
- Manage enabled/disabled store templates

# Secrets Management

- Store encrypted API keys and credentials
- Retrieve encrypted secrets by name

# Background Processing

- Queue color extraction jobs
- Queue artist info fetching jobs
- Queue cover art refresh jobs
- Queue metadata refresh jobs
- Queue artist image download jobs
- Clean up unused artist information

# Statistics & Analytics

- View listening statistics by time period
- Compare listening trends across multiple periods
- Count records by format, type, artist, or genre
- Get collection overview statistics

# Data Import/Export

- Import batch tracks from Last.fm API
- Parse Obsidian music notes with frontmatter
- Export listening data (via statistics views)
