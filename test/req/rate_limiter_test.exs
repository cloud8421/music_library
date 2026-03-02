defmodule Req.RateLimiterTest do
  use ExUnit.Case, async: true

  alias Req.RateLimiter

  describe "attach/2" do
    test "attaches rate_limiter step and sets private fields" do
      request =
        Req.new(url: "https://example.com")
        |> RateLimiter.attach(name: :test_attach, cooldown: 100)

      assert Req.Request.get_private(request, :rate_limiter_name) == :test_attach
      assert Req.Request.get_private(request, :rate_limiter_cooldown) == 100

      step_names = Enum.map(request.request_steps, &elem(&1, 0))
      assert :rate_limiter in step_names
    end

    test "rate_limiter step runs before other request steps" do
      request =
        Req.new(url: "https://example.com")
        |> Req.Request.append_request_steps(log_attempt: fn req -> req end)
        |> RateLimiter.attach(name: :test_order, cooldown: 100)

      step_names = Enum.map(request.request_steps, &elem(&1, 0))
      rate_limiter_index = Enum.find_index(step_names, &(&1 == :rate_limiter))
      log_index = Enum.find_index(step_names, &(&1 == :log_attempt))

      assert rate_limiter_index < log_index
    end
  end

  describe "throttle behavior" do
    test "does not sleep when cooldown is 0" do
      name = :"test_no_sleep_#{System.unique_integer([:positive])}"

      adapter = fn request ->
        {request, Req.Response.new(status: 200, body: "ok")}
      end

      request =
        Req.new(url: "https://example.com", adapter: adapter)
        |> RateLimiter.attach(name: name, cooldown: 0)

      start = System.monotonic_time(:millisecond)
      {:ok, _} = Req.get(request)
      {:ok, _} = Req.get(request)
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 200
    end

    test "enforces cooldown between rapid consecutive requests" do
      name = :"test_cooldown_#{System.unique_integer([:positive])}"
      cooldown = 100

      adapter = fn request ->
        {request, Req.Response.new(status: 200, body: "ok")}
      end

      request =
        Req.new(url: "https://example.com", adapter: adapter)
        |> RateLimiter.attach(name: name, cooldown: cooldown)

      {:ok, _} = Req.get(request)

      start = System.monotonic_time(:millisecond)
      {:ok, _} = Req.get(request)
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed >= cooldown - 50
    end

    test "does not sleep when enough time has elapsed" do
      name = :"test_elapsed_#{System.unique_integer([:positive])}"
      cooldown = 50

      adapter = fn request ->
        {request, Req.Response.new(status: 200, body: "ok")}
      end

      request =
        Req.new(url: "https://example.com", adapter: adapter)
        |> RateLimiter.attach(name: name, cooldown: cooldown)

      {:ok, _} = Req.get(request)
      Process.sleep(cooldown + 10)

      start = System.monotonic_time(:millisecond)
      {:ok, _} = Req.get(request)
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 200
    end

    test "different API names are tracked independently" do
      name_a = :"test_api_a_#{System.unique_integer([:positive])}"
      name_b = :"test_api_b_#{System.unique_integer([:positive])}"
      cooldown = 100

      adapter = fn request ->
        {request, Req.Response.new(status: 200, body: "ok")}
      end

      request_a =
        Req.new(url: "https://example.com", adapter: adapter)
        |> RateLimiter.attach(name: name_a, cooldown: cooldown)

      request_b =
        Req.new(url: "https://example.com", adapter: adapter)
        |> RateLimiter.attach(name: name_b, cooldown: cooldown)

      {:ok, _} = Req.get(request_a)

      start = System.monotonic_time(:millisecond)
      {:ok, _} = Req.get(request_b)
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 200
    end
  end
end
