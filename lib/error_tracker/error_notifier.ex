defmodule ErrorTracker.ErrorNotifier do
  @moduledoc false

  use GenServer
  require Logger

  alias ErrorTracker.ErrorNotifier.Email

  @cleanup_interval :timer.minutes(5)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    if has_valid_config?() do
      attach_telemetry()
      schedule_cleanup()
      {:ok, %{errors: %{}}}
    else
      :ignore
    end
  end

  @impl true
  def handle_info({:telemetry_event, event_name, _measurements, metadata}, state) do
    case event_name do
      [:error_tracker, :error, :new] ->
        reason = truncate_reason(metadata.occurrence.reason)
        {_result, new_state} = maybe_notify(metadata.occurrence, "New Error! (#{reason})", state)
        {:noreply, new_state}

      [:error_tracker, :occurrence, :new] ->
        reason = truncate_reason(metadata.occurrence.reason)
        {_result, new_state} = maybe_notify(metadata.occurrence, "Error: #{reason}", state)
        {:noreply, new_state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:cleanup, state) do
    schedule_cleanup()
    {:noreply, cleanup_old_records(state)}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @doc false
  def handle_telemetry_event(event_name, measurements, metadata, _config) do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      pid -> send(pid, {:telemetry_event, event_name, measurements, metadata})
    end
  end

  # -- Private --

  defp attach_telemetry do
    events = [
      [:error_tracker, :error, :new],
      [:error_tracker, :occurrence, :new]
    ]

    :telemetry.detach("error-tracker-notifications")

    :telemetry.attach_many(
      "error-tracker-notifications",
      events,
      &__MODULE__.handle_telemetry_event/4,
      nil
    )
  end

  defp maybe_notify(occurrence, header, state) do
    error_id = occurrence.error_id
    now = System.system_time(:second)
    throttle_seconds = config()[:throttle_seconds] || 10

    error_state = Map.get(state.errors, error_id, %{count: 0, last_time: 0})
    time_since_last = now - error_state.last_time

    if error_state.last_time == 0 || time_since_last >= throttle_seconds do
      header_with_count = format_header_with_count(header, error_state.count)
      result = Email.send(occurrence, header_with_count)
      updated_errors = Map.put(state.errors, error_id, %{count: 0, last_time: now})
      {result, %{state | errors: updated_errors}}
    else
      updated_error = %{count: error_state.count + 1, last_time: error_state.last_time}
      updated_errors = Map.put(state.errors, error_id, updated_error)

      Logger.debug("Throttled notification for error #{error_id}. Count: #{updated_error.count}")

      {:throttled, %{state | errors: updated_errors}}
    end
  end

  defp cleanup_old_records(state) do
    now = System.system_time(:second)
    one_hour_ago = now - 3600

    cleaned_errors =
      state.errors
      |> Enum.filter(fn {_error_id, %{last_time: last_time}} -> last_time >= one_hour_ago end)
      |> Map.new()

    %{state | errors: cleaned_errors}
  end

  defp format_header_with_count(header, count) when count > 1,
    do: "#{header} (#{count} occurrences)"

  defp format_header_with_count(header, _count), do: header

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp truncate_reason(reason) when is_binary(reason) do
    if String.length(reason) > 80, do: String.slice(reason, 0, 77) <> "...", else: reason
  end

  defp truncate_reason(reason), do: reason |> inspect() |> truncate_reason()

  defp has_valid_config? do
    conf = config()
    not is_nil(conf[:from_email]) and not is_nil(conf[:to_email]) and not is_nil(conf[:mailer])
  end

  defp config do
    Application.get_env(:music_library, __MODULE__, [])
  end
end
