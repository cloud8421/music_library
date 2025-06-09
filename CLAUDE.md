# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Music Library is an Elixir/Phoenix application for managing a personal music collection. It allows users to:

- Add records from MusicBrainz, with optional data overrides
- Manage a collection and wishlist of records with search/filtering capabilities
- Integrate with Last.fm for scrobbles and record tracking
- View statistics about the collection
- Store all data in a single SQLite database

## Development Setup

### Prerequisites

- [mise-en-place](https://mise.jdx.dev) is used for environment management
- Requires Erlang, Elixir, and Node.js (managed by mise)
- Uses [Fluxon UI](https://fluxonui.com/) - requires valid credentials

### Environment Configuration

Required environment variables:

- `LAST_FM_USER`: Last.fm username for Scrobble Activity
- `LAST_FM_API_KEY`: Last.fm API key (secret)
- `OPENAI_KEY`: OpenAI API key (secret)
- `FLUXON_KEY_FINGERPRINT`: Fluxon license fingerprint
- `FLUXON_LICENSE_KEY`: Fluxon license key
- `LOGIN_PASSWORD`: Password for accessing the application (in production)

Create a `mise.local.toml` with required variables (samples in `mise.toml`).

### Initial Setup

```sh
# Install required tools (Erlang, Elixir, Node.js)
mise install

# Setup dependencies and database
mise run dev:setup
```

## Common Commands

### Development

```sh
# Run the Phoenix server
mix phx.server

# Run with an interactive Elixir console
iex -S mix phx.server
# OR
mise run dev:console

# Run static checks (format, credo, gettext)
mise run dev:static-checks

# Show outdated dependencies
mise run deps:outdated

# Update dependencies
mise run deps:update
```

### Testing

```sh
# Run all tests
mix test
# OR
mise run test

# Run a specific test file
mix test test/path/to/test_file.exs

# Run a specific test (line number)
mix test test/path/to/test_file.exs:42
```

### Database

```sh
# Setup database (create and migrate)
mix ecto.setup

# Reset database (drop, create, and migrate)
mix ecto.reset

# Run migrations
mix ecto.migrate
```

### Production

```sh
# Run migrations against production
mise run prod:migrate

# Backup production database to local dev env
mise run prod:backup

# Run HTTP tests against production
mise run prod:test

# Open SSH console to production environment
mise run prod:console
```

### Docker

```sh
# Build and tag Docker image
mise run docker:build

# Push image to registry
mise run docker:push
```

## Architecture

### Database Structure

The application uses SQLite with a unique database design:

- Single `records` table stores all record data with embedded JSON for artists
- Uses a virtual FTS5 table (`records_search_index`) for efficient searching
- `artist_infos` table stores additional artist metadata
- `artist_records` view provides normalized artist-record relationships
- Collection vs. wishlist differentiated by `purchased_at` field (NULL = wishlist)

Tables are synchronized with triggers, and multiple indices exist for performance.

### Code Organization

The application follows standard Phoenix/Elixir structure:

- `lib/music_library`: Core application logic
  - `records/`: Record and collection management
  - `artists/`: Artist data handling
  - `wishlist/`: Wishlist functionality
  - `barcode_scan/`: Barcode scanning features
  - `colors/`: Extract colors for images, e.g. album artworks
  - `secrets/`: Manage encrypted secrets that are stored in the db
- `lib/music_brainz`, `lib/discogs`, `lib/last_fm`: External API integrations
- `lib/music_library_web`: Web interface (Phoenix)
  - `live/`: LiveView implementations
  - `components/`: UI components
  - `controllers/`: Traditional Phoenix controllers

## Git Workflow

Run the following before commits to ensure code quality:

```sh
# Run static checks to ensure code quality
mix do format --check-formatted, credo --strict, gettext.extract --check-up-to-date
```

To set up a pre-commit hook:

```sh
mise generate git-pre-commit --write --task=static-checks-hook
```

