---
name: ui-framework
description: "Use this skill when working with LiveViews, UI components using the Phoenix framework, and in general ANY FILE THAT CONTAINS HTML. Use proactively when editing .heex files, LiveView modules, LiveComponents, or any component module under lib/music_library_web/components/."
metadata:
  managed-by: usage-rules
---

# Project UI Conventions

Before writing or modifying UI code, follow these project-specific rules. They take
precedence over the generic reference material below.

## Checklist

1. **Gettext all user-facing strings.** Every string visible to users must be wrapped
   in `gettext/1` or `pgettext/2`. After adding new strings, run
   `mix gettext.extract --merge` to update `.pot`/`.po` files.

2. **Dark mode always paired.** Every color class needs its dark variant:
   `text-zinc-900 dark:text-zinc-100`, `bg-zinc-50 dark:bg-zinc-800`, etc.

3. **Wishlisted items get dimmed styling:** `opacity-60 hover:opacity-100 transition-opacity`.

4. **Icons inside buttons use the `icon` class** — not explicit size classes like
   `h-5 w-5` or `size-3.5`. Fluxon auto-sizes icons based on the button's `size` prop.

5. **Artist names use `joinphrase`** from MusicBrainz — never join artist names with
   a literal `", "`.

6. **Streams for all collections.** Use LiveView streams, not list assigns. See the
   LiveView reference below for stream patterns.

## Component organization

- Generic UI → `CoreComponents`
- Record-specific → `RecordComponents`
- Scrobble-specific → `ScrobbleComponents`
- Search-specific → `SearchComponents`
- Stats-specific → `StatsComponents`, `ChartComponents`
- Extract a function component when identical markup appears in 3+ places.

## LiveView structure

- `mount/3` sets `@current_section`
- `handle_params/3` loads data and sets `@page_title` (via pattern-matched private `page_title/2`)
- `handle_info/2` receives LiveComponent messages
- LiveComponents communicate with parent via `send(self(), {__MODULE__, msg})`

## Toast notifications

- In LiveViews: `put_toast(socket, :info, "message")` (arity 3)
- In LiveComponents: `put_toast!(:info, "message")` (arity 2)
- User-facing error reasons go through `ErrorMessages.friendly_message/1` — never `inspect(reason)`

## Routes

- Three routes per resource with show modals: `:show`, `:edit` (at `/show/edit`), `:add_*`
- Modals close via `JS.patch` back to the base route
- Search state in URL query params via `push_patch`
- Conditional links: `purchased_at` determines `/collection/` vs `/wishlist/` paths

## Fluxon components

Read `references/fluxon.md` when you need to use a specific Fluxon component —
it contains the full attribute/slot API for each component. You can also search with:

```sh
mix usage_rules.search_docs "component_name" -p fluxon
```

## Visual verification with Chrome DevTools

Use the Chrome DevTools MCP tools to verify UI changes in the running dev server.

### When to screenshot

Take screenshots after **visual** changes — styling, layout, component additions or
removals, responsive adjustments. Skip for logic-only changes (event handlers, assigns
that don't affect rendering).

### Authentication

The dev server requires login. If you get redirected to `/login`, fill the password
field and submit before navigating to your target page:

1. `take_snapshot` to get element UIDs
2. `fill` the password field with the dev password from `config/config.exs`
   (`login_password` under `:music_library, MusicLibraryWeb`)
3. `click` the Login button
4. `navigate_page` to your target route

### Dark mode verification

When your change adds or modifies **color classes, backgrounds, borders, or custom
styling**, take two screenshots:

1. Default (light mode) — screenshot as-is
2. Dark mode — run `evaluate_script` with
   `document.documentElement.classList.add('dark')`, then screenshot

This connects directly to the "Dark mode always paired" checklist rule. Both screenshots
must look correct.

When the change is limited to Fluxon component attributes (e.g., `variant`, `size`) with
no custom color classes, dark mode is handled by the component library — a single
screenshot suffices.

### Before/after comparison

For styling changes, take a screenshot **before** editing so you can describe what
changed. This helps confirm the change had the intended effect and didn't break
surrounding elements.

### Worktree limitation

The dev server at the configured port serves the **main repo**, not a git worktree. If
you are working in a worktree, visual verification reflects the main branch state. To
verify worktree changes visually, start a separate server in the worktree with
`mise run dev:worktree-setup` or apply the change to the main repo first.

---

<!-- usage-rules-skill-start -->
## Additional References

- [ecto](references/ecto.md)
- [elixir](references/elixir.md)
- [html](references/html.md)
- [liveview](references/liveview.md)
- [phoenix](references/phoenix.md)
- [phoenix_ecto](references/phoenix_ecto.md)
- [phoenix_html](references/phoenix_html.md)
- [phoenix_live_dashboard](references/phoenix_live_dashboard.md)
- [phoenix_live_reload](references/phoenix_live_reload.md)
- [phoenix_live_view](references/phoenix_live_view.md)
- [fluxon](references/fluxon.md)

## Searching Documentation

```sh
mix usage_rules.search_docs "search term" -p phoenix -p phoenix_ecto -p phoenix_html -p phoenix_live_dashboard -p phoenix_live_reload -p phoenix_live_view -p fluxon
```

## Available Mix Tasks

- `mix compile.phoenix`
- `mix phx` - Prints Phoenix help information
- `mix phx.digest` - Digests and compresses static files
- `mix phx.digest.clean` - Removes old versions of static assets.
- `mix phx.gen` - Lists all available Phoenix generators
- `mix phx.gen.auth` - Generates authentication logic for a resource
- `mix phx.gen.auth.hashing_library`
- `mix phx.gen.auth.injector`
- `mix phx.gen.auth.migration`
- `mix phx.gen.cert` - Generates a self-signed certificate for HTTPS testing
- `mix phx.gen.channel` - Generates a Phoenix channel
- `mix phx.gen.context` - Generates a context with functions around an Ecto schema
- `mix phx.gen.embedded` - Generates an embedded Ecto schema file
- `mix phx.gen.html` - Generates context and controller for an HTML resource
- `mix phx.gen.json` - Generates context and controller for a JSON resource
- `mix phx.gen.live` - Generates LiveView, templates, and context for a resource
- `mix phx.gen.notifier` - Generates a notifier that delivers emails by default
- `mix phx.gen.presence` - Generates a Presence tracker
- `mix phx.gen.release` - Generates release files and optional Dockerfile for release-based deployments
- `mix phx.gen.schema` - Generates an Ecto schema and migration file
- `mix phx.gen.secret` - Generates a secret
- `mix phx.gen.socket` - Generates a Phoenix socket handler
- `mix phx.routes` - Prints all routes
- `mix phx.server` - Starts applications and their servers
- `mix compile.phoenix_live_view`
- `mix phoenix_live_view.upgrade`
<!-- usage-rules-skill-end -->
