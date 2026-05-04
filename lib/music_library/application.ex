defmodule MusicLibrary.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias MusicLibrary.Assets

  @impl true
  def start(_type, _args) do
    _ = Assets.Cache.new()
    _ = Req.RateLimiter.new()

    children = [
      ErrorTracker.ErrorNotifier,
      MusicLibrary.Vault,
      MusicLibrary.Repo,
      MusicLibrary.BackgroundRepo,
      MusicLibrary.TelemetryRepo,
      MusicLibraryWeb.Telemetry,
      {Oban, Application.fetch_env!(:music_library, Oban)},
      {Ecto.Migrator,
       repos: Application.fetch_env!(:music_library, :ecto_repos), skip: skip_migrations?()},
      {Task.Supervisor, name: MusicLibrary.TaskSupervisor},
      {Phoenix.PubSub, name: MusicLibrary.PubSub},
      # Start a worker by calling: MusicLibrary.Worker.start_link(arg)
      # {MusicLibrary.Worker, arg},
      # Start to serve requests, typically the last entry
      MusicLibraryWeb.Endpoint
    ]

    if Application.fetch_env!(:music_library, :single_line_logging) do
      Logster.attach_phoenix_logger()
    end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MusicLibrary.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MusicLibraryWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def version do
    System.get_env("SOURCE_COMMIT") || "development"
  end

  defp skip_migrations? do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") != nil
  end
end
