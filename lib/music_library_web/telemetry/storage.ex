defmodule MusicLibraryWeb.Telemetry.Storage do
  @moduledoc """
  Telemetry metrics storage backed by SQLite with an in-memory write buffer.

  Telemetry events arrive via `:telemetry` handlers and are forwarded through
  a fast cast to this GenServer. Each cast prepends a datapoint to an
  in-state buffer keyed by metric; no disk I/O happens on the cast path.

  Buffered datapoints are flushed to SQLite on three triggers:

    * a periodic timer (`:flush_interval_ms`, default 5s) which drains the
      full buffer inside a single transaction;
    * a call to `metrics_history/1`, which force-flushes only the buffer
      entry for the requested metric so readers see fresh data without
      waiting for the next tick;
    * `terminate/2`, so graceful shutdown does not lose buffered datapoints.

  Per metric key, at most `:retention_limit` rows (default 32 768) are kept;
  older rows are pruned after each flush.

  Flush failures are logged at `:warning` level; the offending batch is
  dropped (telemetry is not authoritative) and the process keeps running.
  """

  use GenServer

  require Logger

  @retention_limit Application.compile_env!(:music_library, [__MODULE__, :retention_limit])
  @flush_interval_ms Application.compile_env!(:music_library, [__MODULE__, :flush_interval_ms])
  @insert_chunk_size 200

  def metrics_history(metric) do
    GenServer.call(__MODULE__, {:data, metric})
  end

  def start_link(args) do
    {metrics, opts} =
      case args do
        {metrics, opts} when is_list(metrics) and is_list(opts) -> {metrics, opts}
        metrics when is_list(metrics) -> {metrics, [name: __MODULE__]}
      end

    {server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, {metrics, init_opts}, server_opts)
  end

  @impl true
  def init({metrics, opts}) do
    Process.flag(:trap_exit, true)

    for metric <- metrics do
      attach_handler(metric)
    end

    state = %{
      metrics: metrics,
      buffer: %{},
      retention_limit: Keyword.get(opts, :retention_limit, @retention_limit),
      flush_interval_ms: Keyword.get(opts, :flush_interval_ms, @flush_interval_ms),
      flush_ref: nil
    }

    {:ok, %{state | flush_ref: schedule_flush(state.flush_interval_ms)}}
  end

  @impl true
  def terminate(_reason, state) do
    _ = flush_all(state)

    for metric <- state.metrics do
      :telemetry.detach({__MODULE__, metric, self()})
    end

    :ok
  end

  defp attach_handler(%{event_name: name_list} = metric) do
    :telemetry.attach(
      {__MODULE__, metric, self()},
      name_list,
      &__MODULE__.handle_event/4,
      metric
    )
  end

  def handle_event(_event_name, data, metadata, metric) do
    if data = Phoenix.LiveDashboard.extract_datapoint_for_metric(metric, data, metadata) do
      GenServer.cast(__MODULE__, {:telemetry_metric, data, metric})
    end
  end

  @impl true
  def handle_cast({:telemetry_metric, data, metric}, state) do
    key = metric_key(metric)
    entry = datapoint_from_data(data)
    buffer = Map.update(state.buffer, key, [entry], &[entry | &1])
    {:noreply, %{state | buffer: buffer}}
  end

  @impl true
  def handle_call({:data, metric}, _from, state) do
    key = metric_key(metric)
    state = flush_key(state, key)
    {:reply, fetch_datapoints(key), state}
  end

  @impl true
  def handle_info(:flush, state) do
    state = flush_all(state)
    {:noreply, %{state | flush_ref: schedule_flush(state.flush_interval_ms)}}
  end

  defp schedule_flush(interval_ms) do
    Process.send_after(self(), :flush, interval_ms)
  end

  defp datapoint_from_data(data) when is_map(data) do
    %{
      label: Map.get(data, :label),
      measurement: Map.get(data, :measurement, 0),
      time: Map.get(data, :time, System.system_time(:microsecond))
    }
  end

  defp datapoint_from_data(_data) do
    %{label: nil, measurement: 0, time: System.system_time(:microsecond)}
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

  defp flush_all(%{buffer: buffer} = state) when map_size(buffer) == 0, do: state

  defp flush_all(state) do
    keys = Map.keys(state.buffer)

    try do
      MusicLibrary.TelemetryRepo.transaction(fn ->
        Enum.each(keys, &persist_key(state, &1))
      end)
    rescue
      error ->
        Logger.warning(
          "[Telemetry.Storage] flush failed: " <> Exception.format(:error, error, __STACKTRACE__)
        )
    catch
      kind, reason ->
        Logger.warning("[Telemetry.Storage] flush #{kind}: #{inspect(reason)}")
    end

    %{state | buffer: %{}}
  end

  defp flush_key(state, key) do
    case Map.get(state.buffer, key) do
      nil ->
        state

      [] ->
        %{state | buffer: Map.delete(state.buffer, key)}

      _entries ->
        try do
          MusicLibrary.TelemetryRepo.transaction(fn ->
            persist_key(state, key)
          end)
        rescue
          error ->
            Logger.warning(
              "[Telemetry.Storage] flush failed for #{key}: " <>
                Exception.format(:error, error, __STACKTRACE__)
            )
        catch
          kind, reason ->
            Logger.warning("[Telemetry.Storage] flush #{kind} for #{key}: #{inspect(reason)}")
        end

        %{state | buffer: Map.delete(state.buffer, key)}
    end
  end

  defp persist_key(state, key) do
    case Map.get(state.buffer, key, []) do
      [] ->
        :ok

      entries ->
        entries
        |> Enum.reverse()
        |> Enum.map(&Map.put(&1, :metric_key, key))
        |> Enum.chunk_every(@insert_chunk_size)
        |> Enum.each(&MusicLibrary.TelemetryRepo.insert_all("telemetry_datapoints", &1))

        MusicLibrary.TelemetryRepo.query!(
          """
          DELETE FROM telemetry_datapoints
          WHERE metric_key = ?1
            AND id NOT IN (
              SELECT id FROM telemetry_datapoints
              WHERE metric_key = ?1
              ORDER BY id DESC
              LIMIT ?2
            )
          """,
          [key, state.retention_limit]
        )

        :ok
    end
  end

  defp fetch_datapoints(key) do
    case MusicLibrary.TelemetryRepo.query(
           "SELECT label, measurement, time FROM telemetry_datapoints WHERE metric_key = ?1 ORDER BY time ASC",
           [key]
         ) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [label, measurement, time] ->
          %{label: label, measurement: measurement, time: time}
        end)

      {:error, reason} ->
        Logger.warning("[Telemetry.Storage] fetch failed for #{key}: #{inspect(reason)}")
        []
    end
  rescue
    error ->
      Logger.warning(
        "[Telemetry.Storage] fetch raised for #{key}: " <>
          Exception.format(:error, error, __STACKTRACE__)
      )

      []
  end
end
