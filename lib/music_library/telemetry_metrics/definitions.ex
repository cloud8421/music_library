defmodule MusicLibrary.TelemetryMetrics.Definitions do
  @moduledoc """
  Shared telemetry metric definitions, tag helpers, and category assignment.

  This module is the single source of truth for which metrics are collected,
  their categories, tags, drop rules, and display names. It is consumed by:

    * `MusicLibraryWeb.Telemetry` — supervisor that calls `metrics/0`
    * `MusicLibraryWeb.Telemetry.Storage` — uses `MetricKey` for key generation
    * `MusicLibrary.TelemetryMetrics` — API context for bounded overview queries

  ## Category mapping

  Categories are derived from the `reporter_options[:nav]` field (used by
  Phoenix LiveDashboard for grouping). Metrics without a `:nav` value are
  assigned `"VM"` when the event name starts with `vm.` and `"Unknown"`
  otherwise.
  """

  import Telemetry.Metrics

  # ── Namespace filtering ──────────────────────────────────────────────────

  @excluded_namespaces [
    "ErrorTracker",
    "LiveDebugger",
    "Oban",
    "Phoenix"
  ]

  @doc false
  def excluded_namespaces, do: @excluded_namespaces

  # ── Metric definitions ───────────────────────────────────────────────────

  @doc """
  Returns the complete list of `Telemetry.Metrics` definitions.

  This replaces the previous `MusicLibraryWeb.Telemetry.metrics/0` as the
  source of truth. All drop, tag_values, and reporter_options functions
  reference this module's private helpers.
  """
  def metrics do
    [
      # Database Metrics
      summary("music_library.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements",
        reporter_options: [
          nav: "Repo"
        ],
        tags: [:source]
      ),
      summary("music_library.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query",
        reporter_options: [
          nav: "Repo"
        ],
        tags: [:source]
      ),
      summary("music_library.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection",
        reporter_options: [
          nav: "Repo"
        ],
        tags: [:source]
      ),

      # HTTP Metrics
      summary("finch.request.stop.duration",
        unit: {:native, :millisecond},
        tags: [:host],
        tag_values: &add_tags/1,
        drop: &drop_unwanted_hosts/1,
        reporter_options: [
          nav: "External APIs"
        ]
      ),

      # Rate Limiter
      summary("req.rate_limiter.throttle.sleep_ms",
        unit: :millisecond,
        description: "Time spent waiting for rate limit cooldown",
        tags: [:name],
        reporter_options: [
          nav: "External APIs"
        ]
      ),

      # Assets
      summary("music_library.assets.cache_size",
        unit: {:byte, :kilobyte},
        reporter_options: [nav: "Assets"]
      ),
      summary("music_library.assets.content_size",
        unit: {:byte, :megabyte},
        reporter_options: [nav: "Assets"]
      ),

      # Error Tracker
      counter("error_tracker.error.new.system_time",
        description: "New errors tracked",
        reporter_options: [nav: "Error Tracker"]
      ),
      counter("error_tracker.error.resolved.system_time",
        description: "Errors marked as resolved",
        reporter_options: [nav: "Error Tracker"]
      ),
      counter("error_tracker.error.unresolved.system_time",
        description: "Errors marked as unresolved",
        reporter_options: [nav: "Error Tracker"]
      ),
      counter("error_tracker.occurrence.new.system_time",
        description: "New error occurrences",
        reporter_options: [nav: "Error Tracker"]
      ),

      # Oban Job Metrics
      summary("oban.job.stop.duration",
        unit: {:native, :millisecond},
        tags: [:queue, :worker],
        tag_values: &normalize_oban_tags/1,
        reporter_options: [nav: "Oban"]
      ),
      summary("oban.job.stop.queue_time",
        unit: {:native, :millisecond},
        tags: [:queue],
        tag_values: &normalize_oban_tags/1,
        reporter_options: [nav: "Oban"]
      ),
      counter("oban.job.exception.duration",
        tags: [:queue, :worker],
        tag_values: &normalize_oban_tags/1,
        reporter_options: [nav: "Oban"]
      ),

      # Phoenix HTTP Metrics
      summary("phoenix.router_dispatch.stop.duration",
        unit: {:native, :millisecond},
        tags: [:route],
        tag_values: &phoenix_route_tag/1,
        drop: &drop_dev_http_route?/1,
        reporter_options: [nav: "HTTP"]
      ),
      counter("phoenix.router_dispatch.stop.duration",
        tags: [:status],
        tag_values: &phoenix_status_tag/1,
        drop: &drop_dev_http_route?/1,
        reporter_options: [nav: "HTTP"]
      ),
      counter("plug.router_dispatch.exception.duration",
        tags: [:status],
        tag_values: &router_exception_status_tag/1,
        drop: &drop_dev_http_route?/1,
        reporter_options: [nav: "HTTP"]
      ),

      # LiveView Metrics
      summary("phoenix.live_view.mount.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view],
        tag_values: &live_view_tag/1,
        drop: &drop_excluded_namespaces/1,
        reporter_options: [nav: "LiveView"]
      ),
      summary("phoenix.live_view.handle_params.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view],
        tag_values: &live_view_tag/1,
        drop: &drop_excluded_namespaces/1,
        reporter_options: [nav: "LiveView"]
      ),
      summary("phoenix.live_view.render.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view],
        tag_values: &live_view_tag/1,
        drop: &drop_excluded_namespaces/1,
        reporter_options: [nav: "LiveView"]
      ),
      summary("phoenix.live_view.handle_event.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view, :event],
        tag_values: &live_view_event_tag/1,
        drop: &drop_excluded_namespaces/1,
        reporter_options: [nav: "LiveView"]
      ),

      # Markdown Processing Metrics
      summary("markdown.to_html.stop.duration",
        unit: {:native, :millisecond},
        reporter_options: [nav: "Markdown"]
      ),

      # Color Extraction Metrics
      summary("music_library.colors.extract.stop.duration",
        unit: {:native, :millisecond},
        reporter_options: [nav: "Image Processing"]
      ),

      # Image Processing Metrics
      summary("music_library.assets.image.resize.stop.duration",
        unit: {:native, :millisecond},
        reporter_options: [nav: "Image Processing"]
      ),
      summary("music_library.assets.image.convert.stop.duration",
        unit: {:native, :millisecond},
        reporter_options: [nav: "Image Processing"]
      ),

      # Scrobble Rules Metrics
      summary("music_library.scrobble_rules.apply_all_rules.stop.duration",
        unit: {:native, :millisecond},
        tags: [:scrobble_track_count],
        reporter_options: [nav: "Scrobble Rules"]
      ),
      counter("music_library.scrobble_rules.apply_all_rules.exception.duration",
        tags: [:scrobble_track_count],
        reporter_options: [nav: "Scrobble Rules"]
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :megabyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  # ── Tag helpers (Finch / HTTP) ───────────────────────────────────────────

  @doc false
  def add_tags(metadata) do
    req = metadata.request

    Map.merge(metadata, %{
      host: req.host,
      normalized_path: URI.parse(req.path).path
    })
  end

  @doc false
  def drop_unwanted_hosts(metadata) do
    metadata.request.host =~ "archive.org"
  end

  # ── Oban tag helpers ─────────────────────────────────────────────────────

  @doc false
  def normalize_oban_tags(%{job: job}) do
    worker = job.worker |> String.split(".") |> List.last()
    %{queue: job.queue, worker: worker}
  end

  # ── Phoenix HTTP tag helpers ─────────────────────────────────────────────

  @doc false
  def phoenix_route_tag(%{route: route}), do: %{route: route}
  def phoenix_route_tag(_metadata), do: %{route: "unknown"}

  @doc false
  def drop_dev_http_route?(metadata) do
    metadata
    |> http_metric_paths()
    |> Enum.any?(&dev_path?/1)
  end

  defp http_metric_paths(%{conn: %{request_path: request_path}, route: route}) do
    [request_path, route]
  end

  defp http_metric_paths(%{conn: %{request_path: request_path}}), do: [request_path]
  defp http_metric_paths(%{route: route}), do: [route]
  defp http_metric_paths(_metadata), do: []

  defp dev_path?("/dev"), do: true
  defp dev_path?("/dev/" <> _path), do: true
  defp dev_path?(_path), do: false

  @doc false
  def phoenix_status_tag(%{conn: %{status: status}}), do: %{status: to_string(status)}
  def phoenix_status_tag(_metadata), do: %{status: "unknown"}

  @doc false
  def router_exception_status_tag(%{kind: :error, reason: reason}) do
    %{status: reason |> Plug.Exception.status() |> to_string()}
  end

  def router_exception_status_tag(_metadata), do: %{status: "500"}

  # ── LiveView tag helpers ─────────────────────────────────────────────────

  @doc false
  def drop_excluded_namespaces(%{socket: %{view: view}}) do
    live_view_namespace(view) in @excluded_namespaces
  end

  def drop_excluded_namespaces(_metadata), do: false

  @doc false
  def live_view_tag(%{socket: %{view: view}}) do
    %{view: live_view_name(view)}
  end

  def live_view_tag(_metadata), do: %{view: "unknown"}

  @doc false
  def live_view_event_tag(%{socket: %{view: view}, event: event}) do
    %{view: live_view_name(view), event: event}
  end

  def live_view_event_tag(%{event: event}), do: %{view: "unknown", event: event}
  def live_view_event_tag(_metadata), do: %{view: "unknown", event: "unknown"}

  defp live_view_name(view) do
    view |> inspect() |> String.split(".") |> Enum.take(-2) |> Enum.join(".")
  end

  defp live_view_namespace(view) do
    view |> inspect() |> String.split(".") |> hd()
  end

  # ── Descriptor normalization ────────────────────────────────────────────

  @category_map %{
    "Repo" => "repo",
    "HTTP" => "http",
    "External APIs" => "external_apis",
    "Oban" => "oban",
    "Error Tracker" => "error_tracker",
    "LiveView" => "live_view",
    "Assets" => "assets",
    "Markdown" => "markdown",
    "Image Processing" => "image_processing",
    "Scrobble Rules" => "scrobble_rules"
  }

  @doc """
  Returns a stable normalized descriptor map for a Telemetry.Metrics struct.

  The returned map includes:
    * `:key` — the stable metric key (via `MetricKey`)
    * `:name` — dot-joined event name (e.g. `"phoenix.router_dispatch.stop.duration"`)
    * `:kind` — `:summary` or `:counter`
    * `:category` — stable category id (e.g. `"http"`, `"repo"`, `"vm"`)
    * `:tags` — list of tag atoms configured for this metric
    * `:unit` — the measurement unit as a string (e.g. `"millisecond"`) or `nil`
    * `:description` — the metric description or `nil`
    * `:display_name` — human-readable label for the metric
  """
  @spec normalize(Telemetry.Metrics.t()) :: map()
  def normalize(metric) do
    alias MusicLibrary.TelemetryMetrics.MetricKey

    %{
      key: MetricKey.metric_key(metric),
      name: metric.name |> Enum.join("."),
      kind: metric_kind(metric),
      category: category_id(metric),
      tags: metric.tags,
      unit: normalize_unit(metric.unit),
      description: metric.description,
      display_name: display_name(metric)
    }
  end

  @doc """
  Returns the stable category id for a metric.

  Categories are derived from `reporter_options[:nav]` with the following
  fallbacks:
    * event name starting with `vm.` → `"vm"`
    * no nav value → `"unknown"`
  """
  @spec category_id(Telemetry.Metrics.t()) :: String.t()
  def category_id(metric) do
    case get_in(metric.reporter_options, [:nav]) do
      nil -> vm_or_unknown(metric)
      nav -> Map.get(@category_map, nav, vm_or_unknown(metric))
    end
  end

  @doc """
  Returns the list of known category ids across all configured metrics.
  """
  @spec category_ids() :: [String.t()]
  def category_ids do
    metrics() |> Enum.map(&category_id/1) |> Enum.uniq() |> Enum.sort()
  end

  @doc """
  Returns the human-readable name for a category id, or the id itself if unknown.
  """
  @spec category_name(String.t()) :: String.t()
  def category_name(id) do
    @category_map
    |> Enum.find_value(fn {name, cid} -> cid == id && name end) || id
  end

  @doc """
  Returns a list of category metadata maps with `:id`, `:name`, and `:metric_count`.
  """
  @spec categories() :: [%{id: String.t(), name: String.t(), metric_count: non_neg_integer()}]
  def categories do
    grouped =
      metrics()
      |> Enum.group_by(&category_id/1)

    # Preserve order by first appearance in the metric list, then add any
    # categories not yet seen (sorted alphabetically).
    seen_order =
      metrics()
      |> Enum.map(&category_id/1)
      |> Enum.uniq()

    known_ids = Map.keys(grouped) |> MapSet.new()

    for id <- seen_order, MapSet.member?(known_ids, id) do
      %{id: id, name: category_name(id), metric_count: length(Map.get(grouped, id))}
    end
  end

  defp metric_kind(%Telemetry.Metrics.Summary{}), do: :summary
  defp metric_kind(%Telemetry.Metrics.Counter{}), do: :counter

  defp vm_or_unknown(metric) do
    case metric.name do
      [:vm | _] -> "vm"
      _ -> "unknown"
    end
  end

  defp normalize_unit({:native, unit}), do: to_string(unit)
  defp normalize_unit({:byte, unit}), do: to_string(unit)
  # Default unit from Telemetry.Metrics is :unit — treat as "no unit"
  defp normalize_unit(:unit), do: nil
  defp normalize_unit(unit) when is_atom(unit), do: to_string(unit)

  defp display_name(metric) do
    metric.name |> Enum.join(".")
  end
end
