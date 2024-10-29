defmodule MusicLibraryWeb.Router do
  use MusicLibraryWeb, :router

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
  end

  pipeline :require_login do
    plug MusicLibraryWeb.Plug.RequireLogin
  end

  scope "/", MusicLibraryWeb do
    pipe_through :browser

    get "/health", HealthController, :index
    get "/login", SessionController, :new
    post "/sessions/create", SessionController, :create

    scope "/" do
      pipe_through :require_login

      get "/covers/:record_id", CoverController, :show

      live "/", StatsLive.Index, :index

      live "/records", RecordLive.Index, :index
      live "/records/import", RecordLive.Index, :import
      live "/records/:id/edit", RecordLive.Index, :edit

      live "/records/:id", RecordLive.Show, :show
      live "/records/:id/show/edit", RecordLive.Show, :edit

      live "/wishlist", WishlistLive.Index, :index
      live "/wishlist/import", WishlistLive.Index, :import
      live "/wishlist/:id/edit", WishlistLive.Index, :edit

      live "/wishlist/:id", WishlistLive.Show, :show
      live "/wishlist/:id/show/edit", WishlistLive.Show, :edit
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", MusicLibraryWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:music_library, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MusicLibraryWeb.Telemetry
    end
  end
end
