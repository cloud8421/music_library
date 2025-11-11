# GitHub Copilot Instructions for Music Library

## Project Overview

Music Library is an Elixir/Phoenix application for managing a personal music collection with integrations to MusicBrainz and Last.fm. The application uses SQLite for data storage, Phoenix LiveView for real-time UI, and Fluxon UI components for the interface.

## Key Technologies

- **Language**: Elixir (Phoenix Framework)
- **Database**: SQLite with vector extension for AI-powered similarity search
- **Frontend**: Phoenix LiveView, Tailwind CSS, Fluxon UI components
- **Background Jobs**: Oban workers
- **External APIs**: MusicBrainz, Last.fm, OpenAI, Discogs

## Development Guidelines

### Code Style

- Write idiomatic Elixir following Phoenix conventions
- Use functional programming patterns and immutability
- Prefer pattern matching over conditionals
- Use descriptive names (e.g., `user_signed_in?`, `calculate_total`)
- Always use `gettext/1` for user-visible text instead of hardcoded strings

### Project Structure

- **Contexts**: `lib/music_library/` - Core business logic (records, artists, collection, wishlist, search)
- **Web**: `lib/music_library_web/` - Phoenix LiveView modules, controllers, components
- **Workers**: `lib/music_library/worker/` - Oban background job workers
- **External APIs**: `lib/music_brainz/`, `lib/discogs/`, `lib/last_fm/`, `lib/open_ai/`

### Database

- All data stored in SQLite
- Use Ecto for database interactions
- Always preload associations to avoid N+1 queries
- The project uses `records`, `artist_infos`, `scrobble_rules`, `online_store_templates`, `notes`, `assets`, and `secrets` tables

### UI Development

- Use Phoenix LiveView for dynamic interactions
- Use Fluxon UI components instead of custom components where possible
- Implement responsive design with Tailwind CSS
- Use `:if` attributes in HEEx templates for cleaner code
- Follow minimal markup principles

### Testing

- Run tests with `mix test` or `mise run dev:test`
- Run specific tests: `mix test path/to/test.exs:line_number`
- Run failed tests: `mix test --failed`
- Write comprehensive tests using ExUnit

### Development Commands

- Setup: `mise install && mise run dev:setup`
- Run server: `mise run dev:console` (IEx session included)
- Lint: `mise run dev:lint` (format, credo, gettext checks)
- Pre-commit: `mise run dev:precommit`

### Environment Variables

Required for development (see `mise.toml` for samples):
- `LAST_FM_USER`, `LAST_FM_API_KEY`
- `OPENAI_KEY`
- `FLUXON_KEY_FINGERPRINT`, `FLUXON_LICENSE_KEY`
- `LOGIN_PASSWORD` (default: "change me" in dev)

## Important Notes

- **DO NOT** modify production systems - deployment is handled via Coolify
- **Always** run `mise run dev:lint` before committing
- **Reference** the comprehensive `AGENTS.md` file for detailed architectural guidelines
- **Use** Oban workers for background tasks, not GenServers
- **Encrypt** sensitive data using Cloak (see `MusicLibrary.Vault`)

## For More Details

See `AGENTS.md` for comprehensive project architecture, code organization, and AI agent guidelines including usage rules for Elixir, Phoenix, LiveView, Ecto, and Fluxon UI.
