defmodule Req.RateLimiterTest do
  use ExUnit.Case, async: true

  alias Req.RateLimiter
  alias Req.RateLimiter.FakeClock

  setup do
    FakeClock.set(1000)
    :ok
  end

  defp adapter do
    fn request ->
      {request, Req.Response.new(status: 200, body: "ok")}
    end
  end

  describe "new/0" do
    test "enables concurrent writes" do
      assert :ets.info(RateLimiter, :write_concurrency)
    end
  end

  describe "attach/2" do
    test "attaches rate_limiter step and sets private fields" do
      request =
        Req.new(url: "https://example.com")
        |> RateLimiter.attach(name: :test_attach, cooldown: 100, clock: FakeClock)

      assert Req.Request.get_private(request, :rate_limiter_name) == :test_attach
      assert Req.Request.get_private(request, :rate_limiter_cooldown) == 100
      assert Req.Request.get_private(request, :rate_limiter_clock) == FakeClock

      step_names = Enum.map(request.request_steps, &elem(&1, 0))
      assert :rate_limiter in step_names
    end

    test "rate_limiter step runs before other request steps" do
      request =
        Req.new(url: "https://example.com")
        |> Req.Request.append_request_steps(log_attempt: fn req -> req end)
        |> RateLimiter.attach(name: :test_order, cooldown: 100, clock: FakeClock)

      step_names = Enum.map(request.request_steps, &elem(&1, 0))
      rate_limiter_index = Enum.find_index(step_names, &(&1 == :rate_limiter))
      log_index = Enum.find_index(step_names, &(&1 == :log_attempt))

      assert rate_limiter_index < log_index
    end
  end

  describe "throttle behavior" do
    test "does not sleep when cooldown is 0" do
      name = :"test_no_sleep_#{System.unique_integer([:positive])}"

      request =
        Req.new(url: "https://example.com", adapter: adapter())
        |> RateLimiter.attach(name: name, cooldown: 0, clock: FakeClock)

      {:ok, _} = Req.get(request)
      {:ok, _} = Req.get(request)

      # Clock should not have advanced since cooldown is 0
      assert FakeClock.now() == 1000
    end

    test "enforces cooldown between rapid consecutive requests" do
      name = :"test_cooldown_#{System.unique_integer([:positive])}"
      cooldown = 500

      request =
        Req.new(url: "https://example.com", adapter: adapter())
        |> RateLimiter.attach(name: name, cooldown: cooldown, clock: FakeClock)

      {:ok, _} = Req.get(request)

      # No time has passed, so second request must sleep the full cooldown
      {:ok, _} = Req.get(request)

      # Clock advanced exactly by the cooldown amount
      assert FakeClock.now() == 1000 + cooldown
    end

    test "sleeps only the remaining cooldown time" do
      name = :"test_partial_#{System.unique_integer([:positive])}"
      cooldown = 500

      request =
        Req.new(url: "https://example.com", adapter: adapter())
        |> RateLimiter.attach(name: name, cooldown: cooldown, clock: FakeClock)

      {:ok, _} = Req.get(request)

      # Simulate 200ms passing
      FakeClock.advance(200)

      {:ok, _} = Req.get(request)

      # Should have slept the remaining 300ms (500 - 200)
      assert FakeClock.now() == 1000 + 200 + 300
    end

    test "does not sleep when enough time has elapsed" do
      name = :"test_elapsed_#{System.unique_integer([:positive])}"
      cooldown = 500

      request =
        Req.new(url: "https://example.com", adapter: adapter())
        |> RateLimiter.attach(name: name, cooldown: cooldown, clock: FakeClock)

      {:ok, _} = Req.get(request)

      # Simulate more than cooldown passing
      FakeClock.advance(cooldown + 100)

      before_second = FakeClock.now()
      {:ok, _} = Req.get(request)

      # Clock should not have advanced (no sleep needed)
      assert FakeClock.now() == before_second
    end

    test "concurrent callers reserve distinct cooldown slots" do
      name = :"test_concurrent_#{System.unique_integer([:positive])}"
      cooldown = 500
      caller_count = 8
      start_at = 1000
      parent = self()

      request =
        Req.new(
          url: "https://example.com",
          adapter: fn request ->
            send(parent, {:reserved_slot, FakeClock.now()})
            {request, Req.Response.new(status: 200, body: "ok")}
          end
        )
        |> RateLimiter.attach(name: name, cooldown: cooldown, clock: FakeClock)

      tasks =
        for _ <- 1..caller_count do
          Task.async(fn ->
            FakeClock.set(start_at)
            send(parent, {:ready, self()})

            receive do
              :go -> :ok
            after
              1000 -> flunk("timed out waiting to start")
            end

            assert {:ok, _response} = Req.get(request)
          end)
        end

      task_pids =
        for _ <- 1..caller_count do
          assert_receive {:ready, pid}, 1000
          pid
        end

      Enum.each(task_pids, &send(&1, :go))
      Enum.each(tasks, &Task.await(&1, 2000))

      reserved_slots =
        for _ <- 1..caller_count do
          assert_receive {:reserved_slot, reserved_slot}, 1000
          reserved_slot
        end

      sorted_slots = Enum.sort(reserved_slots)

      assert Enum.uniq(sorted_slots) == sorted_slots
      assert sorted_slots == Enum.map(0..(caller_count - 1), &(start_at + &1 * cooldown))

      sorted_slots
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [earlier, later] ->
        assert later - earlier >= cooldown
      end)
    end

    test "emits telemetry event when throttling" do
      name = :"test_telemetry_#{System.unique_integer([:positive])}"
      cooldown = 500

      request =
        Req.new(url: "https://example.com", adapter: adapter())
        |> RateLimiter.attach(name: name, cooldown: cooldown, clock: FakeClock)

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:req, :rate_limiter, :throttle]
        ])

      {:ok, _} = Req.get(request)
      {:ok, _} = Req.get(request)

      assert_received {[:req, :rate_limiter, :throttle], ^ref, %{sleep_ms: 500}, %{name: ^name}}
    end

    test "does not emit telemetry event when no throttling needed" do
      name = :"test_no_telemetry_#{System.unique_integer([:positive])}"
      cooldown = 500

      request =
        Req.new(url: "https://example.com", adapter: adapter())
        |> RateLimiter.attach(name: name, cooldown: cooldown, clock: FakeClock)

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:req, :rate_limiter, :throttle]
        ])

      {:ok, _} = Req.get(request)
      FakeClock.advance(cooldown + 100)
      {:ok, _} = Req.get(request)

      refute_received {[:req, :rate_limiter, :throttle], ^ref, _, _}
    end

    test "different API names are tracked independently" do
      name_a = :"test_api_a_#{System.unique_integer([:positive])}"
      name_b = :"test_api_b_#{System.unique_integer([:positive])}"
      cooldown = 500

      request_a =
        Req.new(url: "https://example.com", adapter: adapter())
        |> RateLimiter.attach(name: name_a, cooldown: cooldown, clock: FakeClock)

      request_b =
        Req.new(url: "https://example.com", adapter: adapter())
        |> RateLimiter.attach(name: name_b, cooldown: cooldown, clock: FakeClock)

      {:ok, _} = Req.get(request_a)

      before_b = FakeClock.now()
      {:ok, _} = Req.get(request_b)

      # API B has no prior request, so no sleep
      assert FakeClock.now() == before_b
    end
  end
end
