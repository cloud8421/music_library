defmodule Req.RateLimiter do
  @moduledoc """
  A Req request step that enforces minimum intervals between requests per API.

  Uses an ETS table to atomically reserve the next available request slot for
  each named API. When a request is made before the reserved slot, the calling
  process sleeps for the remaining time.

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
  Creates the ETS table used to track request slot reservations.
  Call once at application startup.
  """
  @type attach_opts :: [name: atom(), cooldown: non_neg_integer(), clock: module()]

  @spec new() :: :ets.table()
  def new do
    :ets.new(@table, [:set, :public, :named_table, write_concurrency: true])
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
      sleep_ms = reserve_slot(name, cooldown, clock.now())

      if sleep_ms > 0 do
        :telemetry.execute(
          [:req, :rate_limiter, :throttle],
          %{sleep_ms: sleep_ms},
          %{name: name}
        )

        clock.sleep(sleep_ms)
      end
    end

    request
  end

  defp reserve_slot(name, cooldown, now) do
    if :ets.insert_new(@table, {name, now + cooldown}) do
      0
    else
      reserve_existing_slot(name, cooldown, now)
    end
  end

  defp reserve_existing_slot(name, cooldown, now) do
    case :ets.lookup(@table, name) do
      [{^name, current_next_at}] ->
        reserve_current_slot(name, cooldown, now, current_next_at)

      [] ->
        reserve_slot(name, cooldown, now)
    end
  end

  defp reserve_current_slot(name, cooldown, now, current_next_at) do
    slot_at = max(now, current_next_at)
    next_free_at = slot_at + cooldown

    case :ets.select_replace(@table, [
           {{name, current_next_at}, [], [{:const, {name, next_free_at}}]}
         ]) do
      1 -> slot_at - now
      0 -> reserve_existing_slot(name, cooldown, now)
    end
  end
end
