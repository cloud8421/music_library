defmodule MusicLibraryWeb.MetricsController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.TelemetryMetrics

  @doc """
  GET /api/v1/metrics

  Lists available telemetry metric descriptors and categories.
  """
  def index(conn, _params) do
    data = TelemetryMetrics.available_metrics()
    render(conn, :index, categories: data.categories, metrics: data.metrics)
  end

  @doc """
  GET /api/v1/metrics/overview?since=1h&categories=http,oban&top=10

  Returns bounded category summaries of telemetry metrics.
  """
  def overview(conn, params) do
    opts =
      []
      |> put_if_present(:since, params["since"])
      |> put_if_present(:categories, params["categories"])
      |> put_if_present(:top, params["top"])

    case TelemetryMetrics.overview(opts) do
      {:ok, data} ->
        render(conn, :overview, data: data)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(reason)
    end
  end

  # -- private helpers --

  defp put_if_present(kw, _key, nil), do: kw
  defp put_if_present(kw, key, value), do: Keyword.put(kw, key, value)
end
