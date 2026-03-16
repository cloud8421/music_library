defmodule Req.RateLimiter.SystemClock do
  @moduledoc """
  Real clock implementation using `System.monotonic_time/1` and `Process.sleep/1`.
  """

  @behaviour Req.RateLimiter.Clock

  @impl true
  def now, do: System.monotonic_time(:millisecond)

  @impl true
  def sleep(ms), do: Process.sleep(ms)
end
