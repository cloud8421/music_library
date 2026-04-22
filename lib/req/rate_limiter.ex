defmodule Req.RateLimiter do
  @moduledoc """
  A Req request step that enforces minimum intervals between requests per API.

  Uses an ETS table to track the last request timestamp for each named API.
  When a request is made before the cooldown has elapsed, the calling process
  sleeps for the remaining time.

  ## Usage

      Req.new(...)
      |> Req.RateLimiter.attach(name: :music_brainz, cooldown: 500)

  When `cooldown` is 0, the step is a no-op.

  ## Clock

  Time operations are delegated to a clock module implementing
  `Req.RateLimiter.Clock`. Defaults to `Req.RateLimiter.SystemClock`.
  Pass `:clock` in `attach/2` opts to override (useful in tests).
  """

  alias Req.Request

  @table __MODULE__
  @default_clock Req.RateLimiter.SystemClock

  @doc """
  Creates the ETS table used to track request timestamps.
  Call once at application startup.
  """
  @type attach_opts :: [name: atom(), cooldown: non_neg_integer(), clock: module()]

  @spec new() :: :ets.table()
  def new do
    :ets.new(@table, [:set, :public, :named_table])
  end

  @doc """
  Attaches the rate limiter as a request step on the given Req request.

  ## Options

    * `:name` - atom identifying the API (e.g. `:music_brainz`)
    * `:cooldown` - minimum milliseconds between requests
    * `:clock` - module implementing `Req.RateLimiter.Clock` (default: `Req.RateLimiter.SystemClock`)

  """
  @spec attach(Request.t(), attach_opts()) :: Request.t()
  def attach(request, opts) do
    name = Keyword.fetch!(opts, :name)
    cooldown = Keyword.fetch!(opts, :cooldown)
    clock = Keyword.get(opts, :clock, @default_clock)

    request
    |> Request.put_private(:rate_limiter_name, name)
    |> Request.put_private(:rate_limiter_cooldown, cooldown)
    |> Request.put_private(:rate_limiter_clock, clock)
    |> Request.prepend_request_steps(rate_limiter: &throttle/1)
  end

  defp throttle(request) do
    cooldown = Request.get_private(request, :rate_limiter_cooldown)

    if cooldown > 0 do
      name = Request.get_private(request, :rate_limiter_name)
      clock = Request.get_private(request, :rate_limiter_clock)
      now = clock.now()

      case :ets.lookup(@table, name) do
        [{^name, last_at}] ->
          elapsed = now - last_at
          remaining = cooldown - elapsed

          if remaining > 0 do
            :telemetry.execute(
              [:req, :rate_limiter, :throttle],
              %{sleep_ms: remaining},
              %{name: name}
            )

            clock.sleep(remaining)
          end

        [] ->
          :ok
      end

      :ets.insert(@table, {name, clock.now()})
    end

    request
  end
end
