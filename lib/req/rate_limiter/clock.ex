defmodule Req.RateLimiter.Clock do
  @moduledoc """
  Behaviour for time operations used by `Req.RateLimiter`.

  Allows injecting a fake clock in tests for deterministic throttle assertions.
  """

  @callback now() :: integer()
  @callback sleep(non_neg_integer()) :: :ok
end
