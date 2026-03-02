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
  """

  @table __MODULE__

  @doc """
  Creates the ETS table used to track request timestamps.
  Call once at application startup.
  """
  def new do
    :ets.new(@table, [:set, :public, :named_table])
  end

  @doc """
  Attaches the rate limiter as a request step on the given Req request.

  ## Options

    * `:name` - atom identifying the API (e.g. `:music_brainz`)
    * `:cooldown` - minimum milliseconds between requests

  """
  def attach(request, opts) do
    name = Keyword.fetch!(opts, :name)
    cooldown = Keyword.fetch!(opts, :cooldown)

    request
    |> Req.Request.put_private(:rate_limiter_name, name)
    |> Req.Request.put_private(:rate_limiter_cooldown, cooldown)
    |> Req.Request.prepend_request_steps(rate_limiter: &throttle/1)
  end

  defp throttle(request) do
    cooldown = Req.Request.get_private(request, :rate_limiter_cooldown)

    if cooldown > 0 do
      name = Req.Request.get_private(request, :rate_limiter_name)
      now = System.monotonic_time(:millisecond)

      case :ets.lookup(@table, name) do
        [{^name, last_at}] ->
          elapsed = now - last_at
          remaining = cooldown - elapsed

          if remaining > 0 do
            Process.sleep(remaining)
          end

        [] ->
          :ok
      end

      :ets.insert(@table, {name, System.monotonic_time(:millisecond)})
    end

    request
  end
end
