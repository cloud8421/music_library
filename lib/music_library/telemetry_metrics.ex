defmodule MusicLibrary.TelemetryMetrics do
  @moduledoc """
  Read-only telemetry metrics context for the metrics API.

  Provides bounded overview summaries from `telemetry_datapoints` using
  indexed reads through `MusicLibrary.TelemetryRepo`. All queries use
  bound parameters only. No writes are performed.

  ## Configuration

  All defaults and limits are config-driven (`config/config.exs`):

    * `default_since` — default lookback window (e.g. `"1h"`)
    * `max_since` — maximum allowed window (e.g. `"24h"`)
    * `default_top` — default top-N label limit
    * `max_top` — maximum top-N label limit
  """

  alias MusicLibrary.TelemetryMetrics.Definitions
  alias MusicLibrary.TelemetryMetrics.MetricKey
  alias MusicLibrary.TelemetryRepo

  require Logger

  @default_since Application.compile_env!(:music_library, [__MODULE__, :default_since])
  @max_since Application.compile_env!(:music_library, [__MODULE__, :max_since])
  @default_top Application.compile_env!(:music_library, [__MODULE__, :default_top])
  @max_top Application.compile_env!(:music_library, [__MODULE__, :max_top])

  # ── Public API ────────────────────────────────────────────────────────────

  @doc """
  Returns available metric descriptors and category metadata.

  This powers `GET /api/v1/metrics`.
  """
  @spec available_metrics() :: %{
          categories: [map()],
          metrics: [map()]
        }
  def available_metrics do
    %{
      categories: Definitions.categories(),
      metrics: Enum.map(Definitions.metrics(), &Definitions.normalize/1)
    }
  end

  @doc """
  Returns a bounded overview summary of telemetry metrics.

  ## Options

    * `:since` — duration string (`"15m"`, `"1h"`, `"24h"`). Default `#{@default_since}`.
      Values above `#{@max_since}` are clamped.
    * `:categories` — comma-separated category ids or list of strings.
      Unknown categories return an error.
    * `:top` — positive integer top-N limit. Default `#{@default_top}`.
      Values above `#{@max_top}` are clamped.

  ## Returns

    * `{:ok, overview_map}` on success
    * `{:error, reason_map}` on validation failure
  """
  @spec overview(keyword()) :: {:ok, map()} | {:error, map()}
  def overview(opts \\ []) do
    with {:ok, since_string, effective_since_string, since_time, since_clamped} <-
           parse_since(Keyword.get(opts, :since, @default_since)),
         {:ok, category_ids} <- parse_categories(Keyword.get(opts, :categories)),
         {:ok, top, top_clamped} <- parse_top(Keyword.get(opts, :top, @default_top)) do
      generated_at = DateTime.utc_now() |> DateTime.to_iso8601()

      categories =
        build_category_summaries(category_ids, since_time, top)

      {:ok,
       %{
         generated_at: generated_at,
         requested_since: since_string,
         effective_since: effective_since_string,
         since_time: since_time,
         top: top,
         top_clamped: top_clamped || since_clamped,
         categories: categories
       }}
    end
  end

  # ── Parameter parsing ────────────────────────────────────────────────────

  defp parse_since(since) do
    case parse_duration(since) do
      {:ok, since_us} ->
        max_us = parse_duration!(@max_since)

        if since_us > max_us do
          {:ok, since, @max_since, compute_since_time(max_us), true}
        else
          {:ok, since, since, compute_since_time(since_us), false}
        end

      :error ->
        {:error,
         %{error: "Invalid since value", detail: "Expected duration like '15m', '1h', or '24h'"}}
    end
  end

  defp parse_categories(nil), do: {:ok, Definitions.category_ids()}

  defp parse_categories(categories) when is_list(categories) do
    validate_categories(categories)
  end

  defp parse_categories(categories) when is_binary(categories) do
    categories
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> validate_categories()
  end

  defp parse_categories(_other) do
    {:error,
     %{
       error: "Invalid categories parameter",
       detail: "Expected a comma-separated string or list of category ids"
     }}
  end

  defp validate_categories(requested) do
    known = MapSet.new(Definitions.category_ids())
    unknown = Enum.reject(requested, &MapSet.member?(known, &1))

    if unknown == [] do
      {:ok, requested}
    else
      {:error,
       %{
         error: "Unknown categories: #{Enum.join(unknown, ", ")}",
         detail: "Valid categories: #{Enum.join(Enum.sort(known), ", ")}"
       }}
    end
  end

  defp parse_top(top) when is_integer(top) and top > 0 do
    if top > @max_top do
      {:ok, @max_top, true}
    else
      {:ok, top, false}
    end
  end

  defp parse_top(top) do
    case Integer.parse(to_string(top)) do
      {n, ""} when n > 0 ->
        if n > @max_top, do: {:ok, @max_top, true}, else: {:ok, n, false}

      _ ->
        {:error, %{error: "Invalid top value", detail: "Expected a positive integer"}}
    end
  end

  # ── Duration parsing ─────────────────────────────────────────────────────

  # Supported since strings:
  #   15m, 1h, 24h, 30m, 6h, 12h
  @duration_re ~r/^(\d+)(m|h)$/

  defp parse_duration(string) do
    case Regex.run(@duration_re, string, capture: :all_but_first) do
      [value, unit] ->
        n = String.to_integer(value)

        us =
          case unit do
            "m" -> n * 60 * 1_000_000
            "h" -> n * 60 * 60 * 1_000_000
          end

        {:ok, us}

      _ ->
        :error
    end
  end

  defp parse_duration!(string) do
    {:ok, us} = parse_duration(string)
    us
  end

  defp compute_since_time(since_us) do
    System.system_time(:microsecond) - since_us
  end

  # ── Category summaries ───────────────────────────────────────────────────

  defp build_category_summaries(category_ids, since_time, top) do
    # Index metrics by category
    metrics_by_category =
      Definitions.metrics()
      |> Enum.filter(fn m -> Definitions.category_id(m) in category_ids end)
      |> Enum.group_by(&Definitions.category_id/1)

    # Preserve requested category order
    for cat_id <- category_ids,
        metrics = Map.get(metrics_by_category, cat_id, []),
        metrics != [] do
      %{
        id: cat_id,
        name: Definitions.category_name(cat_id),
        metrics: build_metric_summaries(metrics, since_time, top)
      }
    end
  end

  defp build_metric_summaries(metrics, since_time, top) do
    metrics
    |> Enum.map(&build_single_metric_summary(&1, since_time, top))
    |> Enum.reject(&is_nil/1)
  end

  defp build_single_metric_summary(metric, since_time, top) do
    key = MetricKey.metric_key(metric)
    rows = fetch_datapoints(key, since_time)

    groups = compute_groups(rows, metric, top)

    normalized = Definitions.normalize(metric)

    %{
      key: normalized.key,
      name: normalized.name,
      kind: normalized.kind,
      unit: normalized.unit,
      tags: normalized.tags,
      total_count: length(rows),
      groups: groups
    }
  end

  # ── Database access ──────────────────────────────────────────────────────

  defp fetch_datapoints(key, since_time) do
    case TelemetryRepo.query(
           "SELECT label, measurement, time FROM telemetry_datapoints WHERE metric_key = ?1 AND time >= ?2 ORDER BY time ASC",
           [key, since_time]
         ) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [label, measurement, time] ->
          %{label: label, measurement: measurement, time: time}
        end)

      {:error, reason} ->
        Logger.warning("[TelemetryMetrics] fetch failed for #{key}: #{inspect(reason)}")
        []
    end
  rescue
    error ->
      Logger.warning(
        "[TelemetryMetrics] fetch raised for #{key}: " <>
          Exception.format(:error, error, __STACKTRACE__)
      )

      []
  end

  # ── Grouping and statistics ──────────────────────────────────────────────

  defp compute_groups(rows, metric, top) do
    rows
    |> Enum.group_by(& &1.label)
    |> Enum.map(fn {label, points} -> build_group(label, points, metric) end)
    |> sort_groups(metric)
    |> Enum.take(top)
  end

  defp build_group(label, points, metric) do
    measurements = Enum.map(points, & &1.measurement)
    newest = Enum.max_by(points, & &1.time)
    count = length(points)

    kind = metric_kind(metric)

    base = %{
      label: label,
      count: count,
      latest_at: microsecond_to_iso8601(newest.time)
    }

    case kind do
      :counter ->
        # Counters use event count as the primary metric.
        # latest/avg/max/percentiles are null unless proven meaningful.
        Map.merge(base, %{
          latest: nil,
          avg: nil,
          max: nil,
          p50: nil,
          p95: nil,
          p99: nil
        })

      _ ->
        Map.merge(base, %{
          latest: round_float(newest.measurement),
          avg: round_float(mean(measurements)),
          max: round_float(Enum.max(measurements)),
          p50: round_float(percentile(measurements, 50)),
          p95: round_float(percentile(measurements, 95)),
          p99: round_float(percentile(measurements, 99))
        })
    end
  end

  defp metric_kind(%Telemetry.Metrics.Summary{}), do: :summary
  defp metric_kind(%Telemetry.Metrics.Counter{}), do: :counter

  # ── Math helpers ─────────────────────────────────────────────────────────

  defp mean(values) do
    sum = Enum.sum(values)
    sum / length(values)
  end

  # Nearest-rank percentile: sort ascending, pick index = ceil(p/100 * n), 1-based.
  defp percentile([_ | _] = values, p) do
    sorted = Enum.sort(values)
    n = length(sorted)
    index = trunc(Float.ceil(p / 100 * n))
    idx = max(1, min(index, n)) - 1
    Enum.at(sorted, idx)
  end

  defp percentile(_values, _p), do: 0.0

  defp round_float(value) when is_float(value) do
    Float.round(value, 2)
  end

  defp round_float(value) when is_number(value), do: value
  defp round_float(nil), do: nil

  # ── Sorting ──────────────────────────────────────────────────────────────

  # Top-N ordering is deterministic:
  #   timing summaries: highest p95, then highest count, then label ascending
  #   counters: highest count, then label ascending
  #   gauges/value summaries: highest latest, then highest max, then label ascending
  defp sort_groups(groups, metric) do
    kind = metric_kind(metric)

    case kind do
      :counter ->
        Enum.sort_by(groups, &{-(&1.count || 0), &1.label || ""})

      :summary ->
        # Heuristic: if it has timing tags (route, queue, worker, host, source, etc.)
        # sort by p95; otherwise sort by latest (for gauges like vm.memory).
        # We detect "timing" by presence of common timing-tag names.
        if has_timing_tags?(metric) do
          Enum.sort_by(groups, &{-(&1.p95 || 0), -(&1.count || 0), &1.label || ""})
        else
          Enum.sort_by(groups, &{-(&1.latest || 0), -(&1.max || 0), &1.label || ""})
        end
    end
  end

  defp has_timing_tags?(metric) do
    tag_set = MapSet.new(metric.tags)
    timing_tags = MapSet.new([:route, :status, :queue, :worker, :host, :source, :view, :event])
    not MapSet.disjoint?(tag_set, timing_tags)
  end

  # ── Time conversion ──────────────────────────────────────────────────────

  defp microsecond_to_iso8601(nil), do: nil

  defp microsecond_to_iso8601(microseconds) when is_integer(microseconds) do
    seconds = div(microseconds, 1_000_000)
    remainder_us = rem(microseconds, 1_000_000)

    case DateTime.from_unix(seconds, :microsecond, Calendar.ISO) do
      {:ok, dt} ->
        dt
        |> DateTime.add(remainder_us, :microsecond)
        |> DateTime.to_iso8601()

      {:error, _} ->
        nil
    end
  end
end
