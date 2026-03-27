# Music Recognition Feature Design

Audio fingerprint-based music recognition using Chromaprint (client-side WASM) and AcoustID (server-side lookup). Accessible globally via a nav bar button, results displayed in a modal overlay with context-aware actions.

## User Flow

1. User taps "Listen" button in the global nav bar
2. Modal opens with a dashed-border mic button (idle state)
3. User taps "Start listening"
4. JS hook requests microphone access, records ~15 seconds of audio
5. Modal shows listening state: red pulsing mic icon, countdown timer, progress bar
6. After ~15s, recording stops automatically
7. Chromaprint WASM generates fingerprint from PCM audio data
8. Fingerprint + duration pushed to server via `pushEvent`
9. Modal shows processing state: spinner
10. Server calls AcoustID API with fingerprint → gets MusicBrainz recording IDs
11. Server resolves best match to a release via MusicBrainz
12. Server checks collection/wishlist status via `Records.get_release_status/2`
13. Modal shows result with album art, artist, title, status badge, and action buttons:
    - **Collected**: "View in collection" → navigates to `/collection/:id`
    - **Wishlisted**: "View in wishlist" → navigates to `/wishlist/:id`
    - **New**: "Add to collection" / "Add to wishlist" / "Scrobble" → respective actions/pages
    - **Not found**: Error message with "Try again" button
14. "Try again" button resets to idle state

## New Modules

### AcoustId (External API — three-module pattern)

**`AcoustId`** — Facade module.

```elixir
AcoustId.lookup(fingerprint, duration)
# => {:ok, [%{musicbrainz_recording_id: String.t(), score: float()}]}
# => {:error, reason}
```

Calls `AcoustId.Config.resolve(:music_library)` to load configuration, delegates to `AcoustId.API`.

**`AcoustId.API`** — Req HTTP client.

- POST to `https://api.acoustid.org/v2/lookup`
- Parameters: `client` (API key), `fingerprint`, `duration`, `meta=recordings+releases`
- Rate-limited via `Req.RateLimiter.attach(name: :acoust_id, cooldown: 1000)`
- Request/response logging steps
- Parses JSON response, extracts recording IDs with scores

**`AcoustId.Config`** — NimbleOptions schema.

| Field | Type | Required | Default |
|-------|------|----------|---------|
| `api_key` | `:string` | yes | — |
| `req_options` | `:keyword_list` | no | `[]` |
| `api_cooldown` | `:integer` | no | `1000` |

API key stored as environment variable `ACOUSTID_API_KEY`, configured in `config/runtime.exs`.

### MusicRecognition (Context module)

```elixir
MusicRecognition.recognize(fingerprint, duration)
# => {:ok, %MusicRecognition.Result{}}
# => {:error, :not_found | :acoustid_error | term()}
```

Orchestration:
1. `AcoustId.lookup(fingerprint, duration)` — get recording IDs sorted by score
2. For the best match (highest score), call `MusicBrainz.get_recording(recording_id)` to resolve release information (new facade function)
3. `Records.get_release_status(release_id, format)` — check ownership
4. Build and return a `MusicRecognition.Result` struct

### MusicRecognition.Result (Struct)

```elixir
defstruct [:status, :title, :artist_credit, :record_id, :release_id, :release_group_id, :cover_url, :score]

@type t :: %__MODULE__{
  status: :collected | :wishlisted | :new | :not_found,
  title: String.t() | nil,
  artist_credit: String.t() | nil,
  record_id: String.t() | nil,
  release_id: String.t() | nil,
  release_group_id: String.t() | nil,
  cover_url: String.t() | nil,
  score: float()
}
```

### MusicLibraryWeb.Components.MusicRecognizer (LiveComponent)

**States:** `:idle` → `:listening` → `:processing` → `:result` / `:error`

**Assigns:**
- `state` — current UI state atom
- `result` — `%MusicRecognition.Result{}` or `nil`
- `error_message` — string or `nil`
- `mic_access` — `:pending` / `:allowed` / `:denied`

**Events (server):**
- `"start_listening"` — transitions to `:listening`, JS hook starts recording
- `"fingerprint"` — receives `%{"fingerprint" => ..., "duration" => ...}`, transitions to `:processing`, calls `MusicRecognition.recognize/2` via `start_async`
- `"try_again"` — resets to `:idle`
- `"add_to_collection"` — calls `Records.import_from_musicbrainz_release/2` with `purchased_at: now`, navigates to `/collection/:id`
- `"add_to_wishlist"` — calls `Records.import_from_musicbrainz_release/2` without `purchased_at`, navigates to `/wishlist/:id`

**Async handlers:**
- `handle_async(:recognize, {:ok, {:ok, result}}, socket)` — transitions to `:result`
- `handle_async(:recognize, {:ok, {:error, reason}}, socket)` — transitions to `:error`
- `handle_async(:recognize, {:exit, reason}, socket)` — transitions to `:error`

**Colocated JS hook (`.MusicRecognizer`):**

1. `mounted()` — dynamically import `@unimusic/chromaprint`, set up event listeners
2. On `"start_listening"` push from server:
   - Request mic via `navigator.mediaDevices.getUserMedia({audio: true})`
   - Push `mic_allowed` or `mic_denied` back to server
   - Start recording via `AudioContext` + `MediaRecorder`
   - Start 15-second countdown, push `tick` events for UI updates
3. After 15s:
   - Stop recording
   - Feed PCM data to chromaprint WASM → get fingerprint string
   - Push `{"fingerprint", %{fingerprint, duration}}` to server
4. `destroyed()` — stop mic tracks, clean up AudioContext

## Layout Integration

The recognizer button and modal live in the app layout (`layouts/app.html.heex`), accessible from every page.

**Nav bar placement:** Add a button to the existing `button_group` alongside the universal search trigger:

```heex
<.button_group>
  <.universal_search_trigger />
  <.button variant="soft" patch={current_path <> "/recognize"}>
    <.icon name="hero-musical-note" class="icon" />
  </.button>
  <.dropdown ...>
```

**Modal rendering:** Rendered in the app layout, toggled by a live action or URL param. The modal uses `structured_modal` with `on_close` patching back to the current path.

The recognizer needs a route-independent trigger. Two options exist:
1. A dedicated live action on every LiveView (invasive)
2. A JS-driven modal that communicates with the layout's LiveView

Given the app already has the universal search modal as precedent for a global overlay, the recognizer modal follows the same pattern — rendered in the layout, toggled globally.

## UI States (Modal Content)

**Idle:** Dashed-border button with mic icon (matches barcode scanner camera button). Text: "Start listening" / "Tap to identify what's playing".

**Listening:** Red pulsing mic circle, countdown text ("12 seconds remaining"), progress bar filling over 15 seconds. Red accent matches the app's `border-red-500` theme color.

**Processing:** Red-accented spinner. Text: "Recognizing..." / "Looking up fingerprint".

**Result:** Album cover (64px, rounded), artist name (`text-sm/6 text-zinc-700`), title (`text-sm/5 font-semibold`), Fluxon `.badge` showing status (`color="success"` for collected, `color="warning"` for wishlisted, `color="info"` for new). Primary action button (red, `variant="solid"`), secondary "Try again" button (`variant="outline"`).

**Error/Not found:** Error message with "Try again" button.

## New MusicBrainz Facade Function

```elixir
MusicBrainz.get_recording(recording_id)
# => {:ok, %{title, artist_credit, releases: [%{id, title, format, ...}]}}
# => {:error, reason}
```

Calls the MusicBrainz API endpoint `/recording/:id?inc=releases+artists` to resolve a recording ID to its associated releases and artist credits.

## CSP Changes

The `@unimusic/chromaprint` npm package bundles with esbuild, so no new CDN origins needed. `'wasm-unsafe-eval'` is already in `script-src` for the barcode detector. No CSP changes required.

## Configuration

**Application config (`config/config.exs`):**

```elixir
config :music_library, AcoustId,
  api_key: "change me",
  api_cooldown: 1000
```

**Runtime config (`config/runtime.exs`):**

```elixir
config :music_library, AcoustId,
  api_key: System.get_env("ACOUSTID_API_KEY") || raise("Missing ACOUSTID_API_KEY")
```

**Test config (`config/test.exs`):**

```elixir
config :music_library, AcoustId,
  api_key: "test_key",
  req_options: [plug: {Req.Test, AcoustId.API}]
```

## Testing Strategy

**Context tests (`MusicRecognition`):**
- Successful recognition → collected/wishlisted/new status
- AcoustID returns no results → `:not_found`
- AcoustID API error → `:acoustid_error`
- MusicBrainz recording lookup failure → graceful error
- Multiple recordings returned → best score selected

**AcoustId.API tests:**
- Successful lookup → parsed response with recording IDs and scores
- Empty results → `{:ok, []}`
- API error responses → `{:error, reason}`
- All HTTP calls stubbed via `Req.Test`

**LiveComponent tests (Phoenix.LiveViewTest):**
- Modal opens on nav button click
- Mic denied state renders error
- Result with collected status shows "View in collection" button
- Result with new status shows "Add to collection" / "Add to wishlist" / "Scrobble" buttons
- "Try again" resets to idle
- Server-side events tested; JS hook behavior verified via `render_hook/3` for the `fingerprint` event

**MusicBrainz.get_recording tests:**
- Successful recording lookup
- Recording not found
- Stubbed via `Req.Test`

## npm Dependency

Add `@unimusic/chromaprint` to `assets/package.json`. This package provides WASM-based Chromaprint fingerprint generation that runs in the browser.

## Environment Variable

| Variable | Required | Purpose |
|----------|----------|---------|
| `ACOUSTID_API_KEY` | Yes (prod) | AcoustID API authentication |

Add to production environment in Coolify.
