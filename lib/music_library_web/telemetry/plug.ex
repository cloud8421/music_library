defmodule MusicLibraryWeb.Telemetry.Plug do
  @behaviour Plug

  import Plug.Conn

  def init(opts) do
    Keyword.validate!(opts, [:at])
  end

  def call(conn, opts) do
    at = Keyword.fetch!(opts, :at)

    if conn.request_path == at do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, TelemetryMetricsPrometheus.Core.scrape())
      |> halt()
    else
      conn
    end
  end
end
