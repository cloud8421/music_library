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

# Run the server with an interactive Elixir console.
# Note that if you can access the configured MCP server, the application server
# is already running
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

### Guidelines

You are an expert in Elixir, Phoenix, Sqlite, LiveView, and Tailwind CSS.

Code Style and Structure

- Write concise, idiomatic Elixir code with accurate examples.
- Follow Phoenix conventions and best practices.
- Use functional programming patterns and leverage immutability.
- Prefer higher-order functions and recursion over imperative loops.
- Use descriptive variable and function names (e.g., user_signed_in?, calculate_total).
- Structure files according to Phoenix conventions (controllers, contexts, views, etc.).
- Where possible use Fluxon components instead of rolling your own

Database design

- Do not add columns for properties that are not specified in the requirements. Keep database changes to a minimum.

Naming Conventions

- Use snake_case for file names, function names, and variables.
- Use PascalCase for module names.
- Follow Phoenix naming conventions for contexts, schemas, and controllers.

UI and Styling

- Use Phoenix LiveView for dynamic, real-time interactions.
- Implement responsive design with Tailwind CSS. When screen space is limited,
  prefer content-focused flexible layouts over rigid tabular structures.
  Reorganize information hierarchically within each item, grouping related data
  visually while maintaining scanability and preserving all functionality.
- Use Phoenix view helpers and templates to keep views DRY.
- Use minimal markup and avoid nesting DIVs unnecessarily.

Performance Optimization

- Use database indexing effectively.
- Implement caching strategies (ETS, Redis).
- Use Ecto's preload to avoid N+1 queries.
- Optimize database queries using preload, joins, or select.

Key Conventions

- Follow RESTful routing conventions.
- Use contexts for organizing related functionality.
- Implement GenServers for stateful processes and background jobs.
- Use Tasks for concurrent, isolated jobs.

Testing

- Write comprehensive tests using ExUnit.
- Follow TDD practices.

Security

- Implement proper authentication and authorization.
- Use strong parameters in controllers (params validation).
- Protect against common web vulnerabilities (XSS, CSRF, SQL injection).

Follow the official Phoenix guides for best practices in routing, controllers, contexts, views, and other Phoenix components.

<!-- usage-rules-start -->
<!-- usage-rules-header -->

# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the packages listed below.
Before attempting to use any of these packages or to discover if you should use them, review their
usage rules to understand the correct patterns, conventions, and best practices.

<!-- usage-rules-header-end -->

<!-- igniter-start -->
## igniter usage
_A code generation and project patching framework_

[igniter usage rules](deps/igniter/usage-rules.md)
<!-- igniter-end -->
<!-- usage_rules-start -->
## usage_rules usage
_A dev tool for Elixir projects to gather LLM usage rules from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
# Elixir Core Usage Rules

## Pattern Matching
- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies

## Error Handling
- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid
- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design
- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark. 
- Names like `is_thing` should be reserved for guards

## Data Structures
- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing
- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
# OTP Usage Rules

## GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, us `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance
- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->
