defmodule MusicLibrary.TelemetryMetrics.MetricKey do
  @moduledoc """
  Stable metric key generation for telemetry datapoints.

  Keys follow the format:

    `<struct module>:<event.name>:<tags>`

  Examples:

    * `Telemetry.Metrics.Summary:phoenix.router_dispatch.stop.duration:route`
    * `Telemetry.Metrics.Counter:error_tracker.error.new.system_time:`

  The format is intentionally identical to the private `metric_key/1` in
  `MusicLibraryWeb.Telemetry.Storage` so that existing persisted rows remain
  readable.
  """

  @doc """
  Returns the stable metric key for the given `Telemetry.Metrics` struct.

  The format is: `<struct module>:<name>:<tags>`
  where `<name>` and `<tags>` are dot-joined lists of atoms.
  """
  @spec metric_key(Telemetry.Metrics.t()) :: String.t()
  def metric_key(%mod{} = metric) do
    Enum.join(
      [
        inspect(mod),
        Enum.join(metric.name, "."),
        Enum.join(metric.tags, ".")
      ],
      ":"
    )
  end
end
