defmodule MusicLibraryWeb.Telemetry do
  @moduledoc """
  Supervisor for telemetry metrics collection and polling.

  Metric definitions are delegated to `MusicLibrary.TelemetryMetrics.Definitions`
  so that storage (this supervisor), LiveDashboard, and the metrics API share
  a single source of truth.
  """

  use Supervisor

  alias MusicLibrary.TelemetryMetrics.Definitions

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {MusicLibraryWeb.Telemetry.Storage, metrics()},
      # Telemetry poller executes periodic measurements every 30 seconds.
      {:telemetry_poller, measurements: periodic_measurements(), period: 30_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Returns the current metric definitions, delegated to the shared
  `MusicLibrary.TelemetryMetrics.Definitions` module.
  """
  def metrics do
    Definitions.metrics()
  end

  defp periodic_measurements do
    [
      {MusicLibrary.Assets, :track_total_cache_size, []},
      {MusicLibrary.Assets, :track_total_content_size, []}
    ]
  end
end
