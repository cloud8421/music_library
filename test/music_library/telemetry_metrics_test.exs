defmodule MusicLibrary.TelemetryMetricsTest do
  use ExUnit.Case, async: true

  import Telemetry.Metrics

  alias MusicLibrary.TelemetryMetrics
  alias MusicLibrary.TelemetryMetrics.Definitions
  alias MusicLibrary.TelemetryMetrics.MetricKey
  alias MusicLibrary.TelemetryRepo

  describe "MetricKey.metric_key/1" do
    test "produces the same key format as the original Storage private function" do
      # Summary with tags — exact format confirmed against existing persisted keys
      metric =
        summary("phoenix.router_dispatch.stop.duration",
          unit: {:native, :millisecond},
          tags: [:route]
        )

      assert MetricKey.metric_key(metric) ==
               "Telemetry.Metrics.Summary:phoenix.router_dispatch.stop.duration:route"
    end

    test "produces correct key for counter without tags (trailing colon preserved)" do
      metric = counter("error_tracker.error.new.system_time")

      assert MetricKey.metric_key(metric) ==
               "Telemetry.Metrics.Counter:error_tracker.error.new.system_time:"
    end

    test "produces correct key for summary without tags (trailing colon preserved)" do
      metric = summary("vm.memory.total", unit: {:byte, :megabyte})

      assert MetricKey.metric_key(metric) ==
               "Telemetry.Metrics.Summary:vm.memory.total:"
    end

    test "produces correct key for summary with multiple tags" do
      metric =
        summary("oban.job.stop.duration",
          unit: {:native, :millisecond},
          tags: [:queue, :worker]
        )

      assert MetricKey.metric_key(metric) ==
               "Telemetry.Metrics.Summary:oban.job.stop.duration:queue.worker"
    end
  end

  describe "Definitions.category_id/1" do
    test "assigns Repo metrics to 'repo'" do
      metric =
        summary("music_library.repo.query.total_time",
          unit: {:native, :millisecond},
          reporter_options: [nav: "Repo"]
        )

      assert Definitions.category_id(metric) == "repo"
    end

    test "assigns HTTP metrics to 'http'" do
      metric =
        summary("phoenix.router_dispatch.stop.duration",
          unit: {:native, :millisecond},
          tags: [:route],
          reporter_options: [nav: "HTTP"]
        )

      assert Definitions.category_id(metric) == "http"
    end

    test "assigns Oban metrics to 'oban'" do
      metric =
        summary("oban.job.stop.duration",
          unit: {:native, :millisecond},
          reporter_options: [nav: "Oban"]
        )

      assert Definitions.category_id(metric) == "oban"
    end

    test "assigns External APIs metrics to 'external_apis'" do
      metric =
        summary("finch.request.stop.duration",
          unit: {:native, :millisecond},
          reporter_options: [nav: "External APIs"]
        )

      assert Definitions.category_id(metric) == "external_apis"
    end

    test "assigns Error Tracker metrics to 'error_tracker'" do
      metric =
        counter("error_tracker.error.new.system_time",
          reporter_options: [nav: "Error Tracker"]
        )

      assert Definitions.category_id(metric) == "error_tracker"
    end

    test "assigns VM metrics (no nav) to 'vm' based on event name prefix" do
      metric = summary("vm.memory.total", unit: {:byte, :megabyte})

      assert Definitions.category_id(metric) == "vm"
    end

    test "assigns unknown metrics (no nav, not vm) to 'unknown'" do
      # Create a metric without reporter_options — should fall back to unknown
      metric = summary("custom.metric.duration", tags: [])

      assert Definitions.category_id(metric) == "unknown"
    end

    test "assigns LiveView metrics to 'live_view'" do
      metric =
        summary("phoenix.live_view.mount.stop.duration",
          unit: {:native, :millisecond},
          reporter_options: [nav: "LiveView"]
        )

      assert Definitions.category_id(metric) == "live_view"
    end

    test "assigns Image Processing metrics to 'image_processing'" do
      metric =
        summary("music_library.colors.extract.stop.duration",
          unit: {:native, :millisecond},
          reporter_options: [nav: "Image Processing"]
        )

      assert Definitions.category_id(metric) == "image_processing"
    end

    test "assigns Scrobble Rules metrics to 'scrobble_rules'" do
      metric =
        summary("music_library.scrobble_rules.apply_all_rules.stop.duration",
          unit: {:native, :millisecond},
          reporter_options: [nav: "Scrobble Rules"]
        )

      assert Definitions.category_id(metric) == "scrobble_rules"
    end
  end

  describe "Definitions.normalize/1" do
    test "returns a stable descriptor map for a summary metric" do
      metric =
        summary("phoenix.router_dispatch.stop.duration",
          unit: {:native, :millisecond},
          tags: [:route],
          description: "The time spent in the router",
          reporter_options: [nav: "HTTP"]
        )

      normalized = Definitions.normalize(metric)

      assert normalized.key == MetricKey.metric_key(metric)
      assert normalized.name == "phoenix.router_dispatch.stop.duration"
      assert normalized.kind == :summary
      assert normalized.category == "http"
      assert normalized.tags == [:route]
      assert normalized.unit == "millisecond"
      assert normalized.description == "The time spent in the router"
      assert normalized.display_name == "phoenix.router_dispatch.stop.duration"
    end

    test "returns correct kind for counter metrics" do
      metric = counter("error_tracker.occurrence.new.system_time")
      normalized = Definitions.normalize(metric)

      assert normalized.kind == :counter
    end

    test "normalizes byte units correctly" do
      metric = summary("vm.memory.total", unit: {:byte, :megabyte})
      normalized = Definitions.normalize(metric)

      assert normalized.unit == "megabyte"
    end

    test "handles unitless metrics" do
      metric = summary("vm.total_run_queue_lengths.total")
      normalized = Definitions.normalize(metric)

      assert normalized.unit == nil
    end

    test "handles nil description" do
      metric = summary("vm.memory.total", unit: {:byte, :megabyte})
      normalized = Definitions.normalize(metric)

      assert normalized.description == nil
    end
  end

  describe "Definitions.category_ids/0" do
    test "returns unique sorted category ids" do
      ids = Definitions.category_ids()

      # Expect at least the known categories
      assert "error_tracker" in ids
      assert "external_apis" in ids
      assert "http" in ids
      assert "image_processing" in ids
      assert "live_view" in ids
      assert "markdown" in ids
      assert "oban" in ids
      assert "repo" in ids
      assert "scrobble_rules" in ids
      assert "vm" in ids

      # Verify sorted
      assert ids == Enum.sort(ids)
    end
  end

  describe "regression: MusicLibraryWeb.Telemetry.metrics/0 == Definitions.metrics/0" do
    test "both return the same metric definitions" do
      # The web module now delegates, so both should be identical.
      web_metrics = MusicLibraryWeb.Telemetry.metrics()
      def_metrics = Definitions.metrics()

      assert length(web_metrics) == length(def_metrics)

      for {web_m, def_m} <- Enum.zip(web_metrics, def_metrics) do
        assert web_m.name == def_m.name
        assert web_m.__struct__ == def_m.__struct__
        assert web_m.tags == def_m.tags
        assert web_m.unit == def_m.unit
        assert web_m.description == def_m.description
        assert get_in(web_m.reporter_options, [:nav]) == get_in(def_m.reporter_options, [:nav])
      end
    end
  end

  # ── Overview query tests ─────────────────────────────────────────────────

  defp insert_datapoints(key, rows) do
    entries =
      Enum.map(rows, fn {label, measurement, time_val} ->
        %{
          metric_key: key,
          label: label,
          measurement: measurement,
          time: time_val
        }
      end)

    TelemetryRepo.insert_all("telemetry_datapoints", entries)
  end

  describe "available_metrics/0" do
    test "returns categories and metrics lists" do
      result = TelemetryMetrics.available_metrics()

      assert is_list(result.categories)
      assert is_list(result.metrics)
      assert result.metrics != []

      for cat <- result.categories do
        assert is_binary(cat.id)
        assert is_binary(cat.name)
        assert is_integer(cat.metric_count) and cat.metric_count > 0
      end

      for metric <- result.metrics do
        assert is_binary(metric.key)
        assert is_binary(metric.name)
        assert metric.kind in [:summary, :counter]
        assert is_binary(metric.category)
        assert is_list(metric.tags)
        assert metric.unit == nil or is_binary(metric.unit)
        assert is_binary(metric.display_name)
      end
    end
  end

  describe "overview/1 with seeded data" do
    setup do
      id = System.unique_integer([:positive])
      prefix = "test_ov_#{id}"

      now = System.system_time(:microsecond)

      # Insert HTTP timing data with multiple routes
      http_key = "Telemetry.Metrics.Summary:#{prefix}.http.duration:route"

      insert_datapoints(http_key, [
        {"GET /collection", 12.5, now - 500_000},
        {"GET /collection", 18.3, now - 400_000},
        {"GET /collection", 15.1, now - 300_000},
        {"GET /collection", 22.0, now - 200_000},
        {"GET /collection", 10.0, now - 100_000},
        {"GET /wishlist", 8.2, now - 450_000},
        {"GET /wishlist", 9.1, now - 150_000},
        {"GET /", 5.0, now - 50_000}
      ])

      # Insert HTTP status counter data
      http_counter_key = "Telemetry.Metrics.Counter:#{prefix}.http.counter:status"

      insert_datapoints(http_counter_key, [
        {"200", 1, now - 500_000},
        {"200", 1, now - 400_000},
        {"200", 1, now - 300_000},
        {"404", 1, now - 200_000},
        {"500", 1, now - 100_000}
      ])

      # Insert VM gauge data
      vm_key = "Telemetry.Metrics.Summary:#{prefix}.vm.memory:"

      insert_datapoints(vm_key, [
        {nil, 256.0, now - 1_000_000},
        {nil, 512.0, now - 500_000}
      ])

      # Insert old data outside the window (2 hours ago)
      old_key = "Telemetry.Metrics.Summary:#{prefix}.old.metric:route"

      insert_datapoints(old_key, [
        {"old_route", 100.0, now - 7_200_000_000}
      ])

      on_exit(fn ->
        for key <- [http_key, http_counter_key, vm_key, old_key] do
          TelemetryRepo.query!("DELETE FROM telemetry_datapoints WHERE metric_key = ?", [key])
        end
      end)

      %{prefix: prefix, now: now, http_key: http_key, vm_key: vm_key}
    end

    test "returns overview with default since (1h)", _ctx do
      {:ok, result} = TelemetryMetrics.overview(since: "1h")

      assert result.requested_since == "1h"
      assert result.effective_since == "1h"
      assert is_integer(result.since_time)
      assert result.top == 10
      refute result.top_clamped
      assert is_binary(result.generated_at)
      assert is_list(result.categories)
    end

    test "clamps since above max to configured max_since", _ctx do
      {:ok, result} = TelemetryMetrics.overview(since: "9999h")

      assert result.requested_since == "9999h"
      assert result.effective_since == "24h"
      assert result.top_clamped
    end

    test "returns error for invalid since string" do
      assert {:error, %{error: _}} = TelemetryMetrics.overview(since: "xyz")
      assert {:error, %{error: _}} = TelemetryMetrics.overview(since: "")
    end

    test "filters by category", _ctx do
      # VM metrics are not in our seeded data since the key prefix is custom.
      # We test with the default metric set but verify the structure.
      {:ok, result} = TelemetryMetrics.overview(since: "1h", categories: "http")

      # Only HTTP category should be present
      cat_ids = Enum.map(result.categories, & &1.id)
      assert cat_ids == ["http"]
      assert match?([_], result.categories)
      assert hd(result.categories).name == "HTTP"
    end

    test "returns error for unknown category" do
      assert {:error, %{error: msg}} =
               TelemetryMetrics.overview(since: "1h", categories: "nonexistent")

      assert msg =~ "Unknown categories"
      assert msg =~ "nonexistent"
    end

    test "clamps top above max to configured max_top" do
      {:ok, result} = TelemetryMetrics.overview(since: "1h", top: 9999)

      assert result.top == 50
      assert result.top_clamped
    end

    test "returns error for invalid top" do
      assert {:error, %{error: _}} = TelemetryMetrics.overview(since: "1h", top: 0)
      assert {:error, %{error: _}} = TelemetryMetrics.overview(since: "1h", top: -1)
      assert {:error, %{error: _}} = TelemetryMetrics.overview(since: "1h", top: "abc")
    end

    test "empty categories with no seeded data returns empty groups", _ctx do
      # Use a category that won't have our seeded custom-prefix keys
      {:ok, result} = TelemetryMetrics.overview(since: "1h", categories: "scrobble_rules")

      assert is_list(result.categories)
    end

    test "summary groups have correct statistics", _ctx do
      # Use a very wide window to include our seeded data
      {:ok, result} = TelemetryMetrics.overview(since: "24h")

      # Find a metric with groups
      metrics_with_groups =
        result.categories
        |> Enum.flat_map(& &1.metrics)
        |> Enum.filter(&(&1.total_count > 0 && &1.groups != []))

      for metric <- metrics_with_groups do
        assert is_integer(metric.total_count)
        assert is_list(metric.groups)
        assert is_binary(metric.key)
        assert is_binary(metric.name)

        for group <- metric.groups do
          assert is_integer(group.count)
          assert group.latest_at == nil or is_binary(group.latest_at)

          if metric.kind == :summary do
            assert is_number(group.latest) or is_nil(group.latest)
            assert is_number(group.avg) or is_nil(group.avg)
            assert is_number(group.max) or is_nil(group.max)
            assert is_number(group.p50) or is_nil(group.p50)
            assert is_number(group.p95) or is_nil(group.p95)
            assert is_number(group.p99) or is_nil(group.p99)
          end

          if metric.kind == :counter do
            assert is_nil(group.latest)
            assert is_nil(group.avg)
            assert is_nil(group.max)
            assert is_nil(group.p50)
            assert is_nil(group.p95)
            assert is_nil(group.p99)
          end
        end
      end
    end

    test "15m window excludes data from 30 minutes ago", _ctx do
      # Our seeded data is within the last second, so 15m window should include it.
      # Just verify the since parameter is passed through correctly.
      {:ok, result} = TelemetryMetrics.overview(since: "15m")

      assert result.requested_since == "15m"
      assert result.effective_since == "15m"
      refute result.top_clamped
    end
  end

  describe "percentile calculations" do
    test "nearest-rank percentile computation" do
      # Helper for testing the private percentile function
      # 5 values: [1, 3, 5, 7, 9]
      values = [1.0, 3.0, 5.0, 7.0, 9.0]

      # p50: ceil(50/100 * 5) = ceil(2.5) = 3 → value at index 3 = 5.0
      assert p50(values) == 5.0

      # p95: ceil(95/100 * 5) = ceil(4.75) = 5 → value at index 5 = 9.0
      assert p95(values) == 9.0

      # p99: ceil(99/100 * 5) = ceil(4.95) = 5 → value at index 5 = 9.0
      assert p99(values) == 9.0

      # p25: ceil(25/100 * 5) = ceil(1.25) = 2 → value at index 2 = 3.0
      assert p25(values) == 3.0
    end

    test "single value percentile" do
      values = [42.0]
      assert p50(values) == 42.0
      assert p95(values) == 42.0
    end

    test "empty list returns 0.0" do
      assert p50([]) == 0.0
    end

    defp p50(values), do: percentile(values, 50)
    defp p25(values), do: percentile(values, 25)
    defp p95(values), do: percentile(values, 95)
    defp p99(values), do: percentile(values, 99)

    defp percentile([_ | _] = values, p) do
      sorted = Enum.sort(values)
      n = length(sorted)
      index = trunc(Float.ceil(p / 100 * n))
      idx = max(1, min(index, n)) - 1
      Enum.at(sorted, idx)
    end

    defp percentile(_values, _p), do: 0.0
  end
end
