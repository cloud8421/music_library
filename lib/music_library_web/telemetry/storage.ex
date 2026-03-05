defmodule MusicLibraryWeb.Telemetry.Storage do
  use GenServer

  @buffer_size Application.compile_env(
                 :music_library,
                 [__MODULE__, :buffer_size],
                 50
               )

  def metrics_history(metric) do
    GenServer.call(__MODULE__, {:data, metric})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(metrics) do
    Process.flag(:trap_exit, true)

    for metric <- metrics do
      attach_handler(metric)
    end

    {:ok, metrics}
  end

  @impl true
  def terminate(_, metrics) do
    for metric <- metrics do
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
    label = if is_map(data), do: Map.get(data, :label)
    measurement = if is_map(data), do: Map.get(data, :measurement, 0), else: 0

    time =
      if is_map(data),
        do: Map.get(data, :time, System.system_time(:microsecond)),
        else: System.system_time(:microsecond)

    insert_and_prune(key, label, measurement, time)

    {:noreply, state}
  end

  @impl true
  def handle_call({:data, metric}, _from, state) do
    key = metric_key(metric)
    datapoints = fetch_datapoints(key)
    {:reply, datapoints, state}
  end

  defp metric_key(metric) do
    "#{inspect(metric.__struct__)}:#{Enum.join(metric.name, ".")}"
  end

  defp insert_and_prune(key, label, measurement, time) do
    MusicLibrary.TelemetryRepo.query(
      "INSERT INTO telemetry_datapoints (metric_key, label, measurement, time) VALUES (?1, ?2, ?3, ?4)",
      [key, label, measurement, time]
    )

    MusicLibrary.TelemetryRepo.query(
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
      [key, @buffer_size]
    )
  catch
    _, _ -> :ok
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

      _ ->
        []
    end
  catch
    _, _ -> []
  end
end
