defmodule Req.RateLimiter.FakeClock do
  @moduledoc """
  Fake clock for deterministic rate limiter tests.

  Stores the current time in the process dictionary so each test process
  has its own isolated clock state. Works with `async: true`.
  """

  @behaviour Req.RateLimiter.Clock

  @key :fake_clock_now

  @spec set(integer()) :: :ok
  def set(now) do
    Process.put(@key, now)
    :ok
  end

  @spec advance(non_neg_integer()) :: :ok
  def advance(ms) do
    Process.put(@key, now() + ms)
    :ok
  end

  @impl true
  def now do
    Process.get(@key, 0)
  end

  @impl true
  def sleep(ms) do
    advance(ms)
  end
end
