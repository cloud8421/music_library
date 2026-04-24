defmodule MusicLibraryWeb.Telemetry.StorageTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Telemetry.Metrics, only: [summary: 2]

  alias MusicLibrary.TelemetryRepo
  alias MusicLibraryWeb.Telemetry.Storage

  setup do
    id = System.unique_integer([:positive])
    metric = summary("music_library.test.metric_#{id}.duration", tags: [])
    pid = start_supervised!({Storage, {[], [flush_interval_ms: 60_000]}})

    on_exit(fn ->
      TelemetryRepo.query!(
        "DELETE FROM telemetry_datapoints WHERE metric_key LIKE ?1",
        ["%metric_#{id}%"]
      )
    end)

    %{pid: pid, metric: metric, id: id}
  end

  describe "handle_cast/2" do
    test "buffers datapoints in-memory without persisting", %{pid: pid, metric: metric} do
      cast_point(pid, metric, 1.0, 100)
      cast_point(pid, metric, 2.0, 200)

      %{buffer: buffer} = :sys.get_state(pid)
      key = metric_key(metric)

      assert [%{measurement: 2.0, time: 200}, %{measurement: 1.0, time: 100}] =
               Map.get(buffer, key)

      assert db_count(key) == 0
    end

    test "many casts return quickly (no sync I/O on cast path)", %{pid: pid, metric: metric} do
      {time_us, :ok} =
        :timer.tc(fn ->
          for _ <- 1..500, do: cast_point(pid, metric, 1.0, 0)
          _ = :sys.get_state(pid)
          :ok
        end)

      assert time_us < 200_000, "500 casts took #{time_us}us"
    end
  end

  describe "handle_call({:data, metric}, ...)" do
    test "force-flushes the requested metric and returns persisted rows", %{
      pid: pid,
      metric: metric
    } do
      cast_point(pid, metric, 42.0, 1000)

      result = GenServer.call(pid, {:data, metric})

      assert [%{measurement: m, time: 1000, label: nil}] = result
      assert_in_delta m, 42.0, 0.001
      assert db_count(metric_key(metric)) == 1
    end

    test "only flushes the requested metric, leaves others buffered", %{
      pid: pid,
      metric: metric_a,
      id: id
    } do
      metric_b = summary("music_library.test.metric_#{id}_b.duration", tags: [])

      cast_point(pid, metric_a, 1.0, 1)
      cast_point(pid, metric_b, 2.0, 2)

      _ = GenServer.call(pid, {:data, metric_a})

      assert db_count(metric_key(metric_a)) == 1
      assert db_count(metric_key(metric_b)) == 0

      %{buffer: buffer} = :sys.get_state(pid)
      refute Map.has_key?(buffer, metric_key(metric_a))
      assert [%{measurement: 2.0}] = Map.get(buffer, metric_key(metric_b))
    end

    test "returns empty list when nothing has been cast", %{pid: pid, metric: metric} do
      assert GenServer.call(pid, {:data, metric}) == []
    end
  end

  describe "periodic :flush" do
    test "drains the full buffer to SQLite", %{pid: pid, metric: metric, id: id} do
      metric_b = summary("music_library.test.metric_#{id}_b.duration", tags: [])
      cast_point(pid, metric, 1.5, 10)
      cast_point(pid, metric_b, 2.5, 20)

      send(pid, :flush)
      _ = :sys.get_state(pid)

      assert db_count(metric_key(metric)) == 1
      assert db_count(metric_key(metric_b)) == 1

      %{buffer: buffer} = :sys.get_state(pid)
      assert buffer == %{}
    end

    test "prunes rows above retention_limit per metric", %{id: id} do
      metric = summary("music_library.test.metric_#{id}_r.duration", tags: [])

      pid =
        start_supervised!({Storage, {[], [retention_limit: 3, flush_interval_ms: 60_000]}},
          id: :storage_retention
        )

      for n <- 1..10, do: cast_point(pid, metric, n / 1.0, n)
      send(pid, :flush)
      _ = :sys.get_state(pid)

      key = metric_key(metric)
      assert db_count(key) == 3

      {:ok, %{rows: rows}} =
        TelemetryRepo.query(
          "SELECT time FROM telemetry_datapoints WHERE metric_key = ?1 ORDER BY time ASC",
          [key]
        )

      assert rows == [[8], [9], [10]]
    end
  end

  describe "terminate/2" do
    test "flushes the buffer on shutdown", %{pid: pid, metric: metric} do
      cast_point(pid, metric, 7.0, 5000)

      :ok = stop_supervised(MusicLibraryWeb.Telemetry.Storage)

      {:ok, %{rows: rows}} =
        TelemetryRepo.query(
          "SELECT measurement, time FROM telemetry_datapoints WHERE metric_key = ?1",
          [metric_key(metric)]
        )

      assert [[_, 5000]] = rows
      refute Process.alive?(pid)
    end
  end

  describe "error handling" do
    test "logs a warning and keeps running when the flush raises", %{pid: pid, metric: metric} do
      bad = %{measurement: {:not_a_number}, time: 1}
      GenServer.cast(pid, {:telemetry_metric, bad, metric})

      log =
        capture_log(fn ->
          send(pid, :flush)
          _ = :sys.get_state(pid)
        end)

      assert log =~ "[Telemetry.Storage] flush"
      assert Process.alive?(pid)

      %{buffer: buffer} = :sys.get_state(pid)
      assert buffer == %{}
    end
  end

  defp cast_point(pid, metric, measurement, time) do
    GenServer.cast(
      pid,
      {:telemetry_metric, %{measurement: measurement, time: time}, metric}
    )
  end

  defp db_count(key) do
    {:ok, %{rows: [[count]]}} =
      TelemetryRepo.query(
        "SELECT COUNT(*) FROM telemetry_datapoints WHERE metric_key = ?1",
        [key]
      )

    count
  end

  defp metric_key(metric) do
    Enum.join(
      [
        inspect(metric.__struct__),
        Enum.join(metric.name, "."),
        Enum.join(metric.tags, ".")
      ],
      ":"
    )
  end
end
