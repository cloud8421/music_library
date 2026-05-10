defmodule MusicLibraryWeb.Router do
  use MusicLibraryWeb, :router
  use ErrorTracker.Integrations.Plug

  import MusicLibraryWeb.Auth, only: [require_logged_in: 2, require_api_token: 2]
  import Oban.Web.Router

  # Content Security Policy: restricts resource loading to same-origin by default,
  # allows inline styles/scripts and Inter font from rsms.me, album art from
  # Last.fm CDN, Brave Search, and Cover Art Archive, WASM from jsdelivr (barcode-detector),
  # and prevents framing. In dev, allows LiveDebugger and Phoenix dev assets from 127.0.0.1.
  @dev_origins if(Mix.env() == :dev, do: " http://127.0.0.1:* ws://127.0.0.1:*", else: "")
  @img_origins "https://lastfm.freetls.fastly.net https://imgs.search.brave.com " <>
                 "https://coverartarchive.org https://archive.org " <>
                 "https://*.archive.org https://www.google.com https://*.gstatic.com"

  @csp_policy "default-src 'self'" <>
                "; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' #{@dev_origins}" <>
                "; style-src 'self' 'unsafe-inline' https://rsms.me#{@dev_origins}" <>
                "; font-src 'self' https://rsms.me" <>
                "; img-src 'self' data: blob: #{@img_origins}" <>
                "; worker-src 'self' blob:" <>
                "; connect-src 'self' https://fastly.jsdelivr.net#{@dev_origins}" <>
                "; frame-ancestors 'self'" <>
                "; base-uri 'self'"

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MusicLibraryWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" => @csp_policy
    }
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :require_api_token
  end

  pipeline :logged_in do
    plug :require_logged_in
  end

  scope "/", MusicLibraryWeb do
    pipe_through :browser

    get "/health", HealthController, :index
    get "/login", SessionController, :new
    post "/sessions/create", SessionController, :create

    # Deliberately outside the `:logged_in` pipeline: this is the OAuth
    # callback from Last.fm and the third-party redirect can't carry our
    # session cookie. See `MusicLibraryWeb.LastFmController` moduledoc for
    # the full trust boundary.
    get "/auth/last_fm/callback", LastFmController, :callback

    get "/public/assets/:transform_payload", AssetController, :show

    scope "/" do
      pipe_through :logged_in

      get "/backup", ArchiveController, :backup

      get "/assets/:transform_payload", AssetController, :show

      live_session :default,
        on_mount: [
          MusicLibraryWeb.Hooks.StaticAssets,
          MusicLibraryWeb.Hooks.GetTimezone,
          MusicLibraryWeb.Hooks.ShowToast
        ] do
        live "/", StatsLive.Index, :index

        live "/collection", CollectionLive.Index, :index
        live "/collection/import", CollectionLive.Index, :import
        live "/collection/scan", CollectionLive.Index, :barcode_scan
        live "/collection/:id/edit", CollectionLive.Index, :edit

        live "/collection/:id", CollectionLive.Show, :show
        live "/collection/:id/show/edit", CollectionLive.Show, :edit

        live "/wishlist", WishlistLive.Index, :index
        live "/wishlist/import", WishlistLive.Index, :import
        live "/wishlist/:id/edit", WishlistLive.Index, :edit

        live "/wishlist/:id", WishlistLive.Show, :show
        live "/wishlist/:id/show/edit", WishlistLive.Show, :edit

        live "/artists/:musicbrainz_id", ArtistLive.Show, :show
        live "/artists/:musicbrainz_id/import", ArtistLive.Show, :import
        live "/artists/:musicbrainz_id/edit", ArtistLive.Show, :edit

        live "/record-sets", RecordSetLive.Index, :index
        live "/record-sets/new", RecordSetLive.Index, :new
        live "/record-sets/:id/edit", RecordSetLive.Index, :edit
        live "/record-sets/:id/add-record", RecordSetLive.Index, :add_record

        live "/record-sets/:id", RecordSetLive.Show, :show
        live "/record-sets/:id/show/edit", RecordSetLive.Show, :edit
        live "/record-sets/:id/show/add-record", RecordSetLive.Show, :add_record

        live "/scrobble-rules", ScrobbleRulesLive.Index, :index
        live "/scrobble-rules/new", ScrobbleRulesLive.Index, :new
        live "/scrobble-rules/:id/edit", ScrobbleRulesLive.Index, :edit

        live "/online-store-templates", OnlineStoreTemplateLive.Index, :index
        live "/online-store-templates/new", OnlineStoreTemplateLive.Index, :new
        live "/online-store-templates/:id/edit", OnlineStoreTemplateLive.Index, :edit

        live "/scrobbled-tracks", ScrobbledTracksLive.Index, :index
        live "/scrobbled-tracks/:scrobbled_at_uts/edit", ScrobbledTracksLive.Index, :edit

        live "/scrobble", ScrobbleLive.Index, :index
        live "/scrobble/:rg_id", ScrobbleLive.ReleaseGroupShow, :show
        live "/scrobble/:rg_id/releases/:release_id", ScrobbleLive.ReleaseShow, :show

        live "/maintenance", MaintenanceLive.Index, :index
      end
    end
  end

  scope "/api/v1", MusicLibraryWeb do
    pipe_through :api

    get "/collection/latest", CollectionController, :latest
    get "/collection/random", CollectionController, :random
    get "/collection/on_this_day", CollectionController, :on_this_day
    get "/collection", CollectionController, :index
    post "/collection/:record_id/scrobble", CollectionController, :scrobble
    get "/errors", ErrorController, :index
    get "/errors/:id", ErrorController, :show
    post "/errors/:id/mute", ErrorController, :mute
    post "/errors/:id/unmute", ErrorController, :unmute
    post "/errors/:id/resolve", ErrorController, :resolve
    post "/errors/:id/unresolve", ErrorController, :unresolve
    get "/assets/:transform_payload", AssetController, :show
    get "/backup", ArchiveController, :backup
  end

  if Application.compile_env(:music_library, :monitoring_routes) do
    import Phoenix.LiveDashboard.Router
    use ErrorTracker.Web, :router

    pipeline :dev_dashboard do
      plug :generate_csp_nonces
      plug :put_dev_csp
    end

    scope "/dev" do
      pipe_through [:browser, :logged_in, :dev_dashboard]

      live_dashboard "/dashboard",
        metrics: MusicLibraryWeb.Telemetry,
        metrics_history: {MusicLibraryWeb.Telemetry.Storage, :metrics_history, []},
        ecto_repos: [MusicLibrary.Repo, MusicLibrary.BackgroundRepo, MusicLibrary.TelemetryRepo],
        csp_nonce_assign_key: %{
          img: :img_nonce,
          style: :style_nonce,
          script: :script_nonce
        }

      oban_dashboard "/oban",
        csp_nonce_assign_key: %{
          img: :img_nonce,
          style: :style_nonce,
          script: :script_nonce
        }

      error_tracker_dashboard "/errors",
        csp_nonce_assign_key: %{
          img: :img_nonce,
          style: :style_nonce,
          script: :script_nonce
        }
    end
  end

  defp generate_csp_nonces(conn, _opts) do
    nonce = Base.encode64(:crypto.strong_rand_bytes(16), padding: false)

    conn
    |> assign(:img_nonce, nonce)
    |> assign(:style_nonce, nonce)
    |> assign(:script_nonce, nonce)
  end

  # Replaces the default CSP with a dev-specific policy that adds nonce-based
  # exceptions for scripts, styles, and images, allowing Phoenix dev tools
  # (live reload, debug toolbar) to load alongside the standard policy.
  defp put_dev_csp(conn, _opts) do
    nonce = conn.assigns[:script_nonce]

    csp =
      "default-src 'self'" <>
        "; script-src 'self' 'nonce-#{nonce}'" <>
        "; style-src 'self' 'unsafe-inline' 'nonce-#{nonce}' https://rsms.me" <>
        "; font-src 'self' data: https://rsms.me" <>
        "; img-src 'self' data: blob: 'nonce-#{nonce}' #{@img_origins}" <>
        "; connect-src 'self' https://fastly.jsdelivr.net" <>
        "; frame-ancestors 'self'" <>
        "; base-uri 'self'"

    delete_resp_header(conn, "content-security-policy")
    |> put_resp_header("content-security-policy", csp)
  end

  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through [:browser, :logged_in]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
