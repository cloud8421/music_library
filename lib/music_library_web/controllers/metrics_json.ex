defmodule MusicLibraryWeb.MetricsJSON do
  @moduledoc """
  JSON rendering for the /api/v1/metrics endpoints.
  """
  use MusicLibraryWeb, :json

  def index(%{categories: categories, metrics: metrics}) do
    %{
      categories: Enum.map(categories, &category/1),
      metrics: Enum.map(metrics, &metric_descriptor/1)
    }
  end

  def overview(%{data: data}) do
    %{
      generated_at: data.generated_at,
      requested_since: data.requested_since,
      effective_since: data.effective_since,
      since_time: data.since_time,
      top: data.top,
      top_clamped: data.top_clamped,
      categories: Enum.map(data.categories, &category_overview/1)
    }
  end

  defp category(c) do
    %{
      id: c.id,
      name: c.name,
      metric_count: c.metric_count
    }
  end

  defp metric_descriptor(m) do
    %{
      key: m.key,
      name: m.name,
      kind: m.kind,
      category: m.category,
      tags: m.tags,
      unit: m.unit,
      description: m.description
    }
  end

  defp category_overview(c) do
    %{
      id: c.id,
      name: c.name,
      metrics: Enum.map(c.metrics, &metric_summary/1)
    }
  end

  defp metric_summary(m) do
    %{
      key: m.key,
      name: m.name,
      kind: m.kind,
      unit: m.unit,
      tags: m.tags,
      total_count: m.total_count,
      groups: Enum.map(m.groups, &group_summary/1)
    }
  end

  defp group_summary(g) do
    %{
      label: g.label,
      count: g.count,
      latest: g.latest,
      latest_at: g.latest_at,
      avg: g.avg,
      max: g.max,
      p50: g.p50,
      p95: g.p95,
      p99: g.p99
    }
  end
end
