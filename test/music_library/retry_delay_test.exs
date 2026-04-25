defmodule MusicLibrary.RetryDelayTest do
  use ExUnit.Case, async: true

  alias MusicLibrary.RetryDelay

  describe "retry_after_seconds/1" do
    test "parses integer seconds" do
      response = response(%{"retry-after" => ["42"]})

      assert RetryDelay.retry_after_seconds(response) == 42
    end

    test "clamps parsed values to safe bounds" do
      assert RetryDelay.retry_after_seconds(response(%{"retry-after" => ["1"]})) == 5
      assert RetryDelay.retry_after_seconds(response(%{"retry-after" => ["999"]})) == 300
    end

    test "returns nil for missing or malformed values" do
      assert RetryDelay.retry_after_seconds(response(%{})) == nil
      assert RetryDelay.retry_after_seconds(response(%{"retry-after" => ["tomorrow"]})) == nil
      assert RetryDelay.retry_after_seconds(response(%{"retry-after" => ["-1"]})) == nil
    end

    test "clamps zero to the safe minimum" do
      assert RetryDelay.retry_after_seconds(response(%{"retry-after" => ["0"]})) == 5
    end
  end

  describe "reset_seconds/2" do
    test "uses the largest valid comma-separated reset window" do
      response = response(%{"x-ratelimit-reset" => ["12, 60"]})

      assert RetryDelay.reset_seconds(response, "x-ratelimit-reset") == 60
    end

    test "ignores malformed windows and clamps the selected value" do
      response = response(%{"x-ratelimit-reset" => ["bad, 2, 600"]})

      assert RetryDelay.reset_seconds(response, "x-ratelimit-reset") == 300
    end
  end

  describe "openai_reset_seconds/1" do
    test "uses the largest reset across retry-after, request, and token windows" do
      response =
        response(%{
          "retry-after" => ["10"],
          "x-ratelimit-reset-requests" => ["20s"],
          "x-ratelimit-reset-tokens" => ["1m30s"]
        })

      assert RetryDelay.openai_reset_seconds(response) == 90
    end

    test "clamps sub-second OpenAI durations to the safe minimum" do
      response = response(%{"x-ratelimit-reset-requests" => ["120ms"]})

      assert RetryDelay.openai_reset_seconds(response) == 5
    end

    test "parses minute durations and clamps long values" do
      response = response(%{"x-ratelimit-reset-tokens" => ["10m"]})

      assert RetryDelay.openai_reset_seconds(response) == 300
    end

    test "returns nil when OpenAI reset headers are absent or malformed" do
      assert RetryDelay.openai_reset_seconds(response(%{})) == nil

      assert RetryDelay.openai_reset_seconds(
               response(%{"x-ratelimit-reset-requests" => ["soon"]})
             ) == nil
    end
  end

  defp response(headers), do: Req.Response.new(status: 429, headers: headers)
end
