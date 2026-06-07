defmodule MusicLibraryWeb.TelemetryTest do
  use ExUnit.Case, async: true

  alias MusicLibraryWeb.Telemetry

  @dashboard_views [
    Phoenix.LiveDashboard.PageLive,
    Oban.Web.DashboardLive,
    ErrorTracker.Web.Live.Dashboard
  ]

  test "LiveView metrics discard monitoring dashboard views" do
    for metric <- live_view_metrics(), view <- @dashboard_views do
      refute metric.keep.(%{socket: %{view: view}})
    end
  end

  test "LiveView metrics keep application views" do
    for metric <- live_view_metrics() do
      assert metric.keep.(%{socket: %{view: MusicLibraryWeb.StatsLive.Index}})
    end
  end

  defp live_view_metrics do
    Telemetry.metrics()
    |> Enum.filter(&(Enum.take(&1.name, 2) == [:phoenix, :live_view]))
  end
end
