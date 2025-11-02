defmodule MusicLibraryWeb.Router do
  use MusicLibraryWeb, :router

  import MusicLibraryWeb.Auth, only: [require_logged_in: 2, require_api_token: 2]
  import Oban.Web.Router
  import Lotus.Web.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MusicLibraryWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
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

    get "/auth/last_fm/callback", LastFmController, :callback

    scope "/" do
      pipe_through :logged_in

      get "/backup", ArchiveController, :backup

      get "/assets/:transform_payload", AssetController, :show

      live_session :default,
        on_mount: [MusicLibraryWeb.Hooks.StaticAssets, MusicLibraryWeb.Hooks.GetTimezone] do
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

        live "/scrobble-rules", ScrobbleRulesLive.Index, :index
        live "/scrobble-rules/new", ScrobbleRulesLive.Index, :new
        live "/scrobble-rules/:id/edit", ScrobbleRulesLive.Index, :edit

        live "/online-store-templates", OnlineStoreTemplateLive.Index, :index
        live "/online-store-templates/new", OnlineStoreTemplateLive.Index, :new
        live "/online-store-templates/:id/edit", OnlineStoreTemplateLive.Index, :edit

        live "/scrobbled-tracks", ScrobbledTracksLive.Index, :index
        live "/scrobbled-tracks/:scrobbled_at_uts/edit", ScrobbledTracksLive.Index, :edit

        live "/scrobble", ScrobbleLive.Index, :index
        live "/scrobble/:release_id", ScrobbleLive.Show, :show
      end
    end
  end

  scope "/api", MusicLibraryWeb do
    pipe_through :api

    get "/collection/latest", CollectionController, :latest
    get "/collection/random", CollectionController, :random
    get "/collection/on_this_day", CollectionController, :on_this_day
    get "/collection", CollectionController, :index
    get "/assets/:transform_payload", AssetController, :show
    get "/backup", ArchiveController, :backup
  end

  if Application.compile_env(:music_library, :monitoring_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:browser, :logged_in]

      live_dashboard "/dashboard",
        metrics: MusicLibraryWeb.Telemetry,
        metrics_history: {MusicLibraryWeb.Telemetry.Storage, :metrics_history, []},
        ecto_repos: [MusicLibrary.Repo, MusicLibrary.BackgroundRepo]

      oban_dashboard "/oban"

      lotus_dashboard("/lotus")

      live "/maintenance", MusicLibraryWeb.MaintenanceLive.Index, :index
    end
  end
end
