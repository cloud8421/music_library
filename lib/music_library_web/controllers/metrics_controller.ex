defmodule MusicLibraryWeb.MetricsController do
  use MusicLibraryWeb, :controller

  def index(conn, _params) do
    send_resp(conn, 200, TelemetryMetricsPrometheus.Core.scrape())
  end
end
