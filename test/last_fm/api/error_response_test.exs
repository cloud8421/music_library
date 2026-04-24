defmodule LastFm.API.ErrorResponseTest do
  use ExUnit.Case, async: true

  alias LastFm.API.ErrorResponse

  describe "new/2" do
    test "maps known error codes to atoms" do
      assert %ErrorResponse{error: :rate_limit_exceeded, message: "limit"} =
               ErrorResponse.new(29, "limit")

      assert %ErrorResponse{error: :invalid_session_key} = ErrorResponse.new(9, "bad")
      assert %ErrorResponse{error: :service_offline} = ErrorResponse.new(11, "down")
    end
  end

  describe "retryable_error?/1" do
    test "returns true for transient error atoms" do
      for atom <- [:transient_error, :service_offline, :rate_limit_exceeded, :operation_failed] do
        assert ErrorResponse.retryable_error?(atom), "expected #{atom} to be retryable"
      end
    end

    test "returns false for permanent error atoms" do
      for atom <- [:invalid_session_key, :invalid_api_key, :authentication_failed] do
        refute ErrorResponse.retryable_error?(atom), "expected #{atom} to be non-retryable"
      end
    end
  end

  describe "retry_delay/1 and retry_delay_seconds/1" do
    test "returns a delay in milliseconds for retryable atoms" do
      assert ErrorResponse.retry_delay(:rate_limit_exceeded) == 60_000
      assert ErrorResponse.retry_delay(:service_offline) == 30_000
      assert ErrorResponse.retry_delay(:transient_error) == 5_000
      assert ErrorResponse.retry_delay(:operation_failed) == 5_000
    end

    test "returns nil for non-retryable atoms" do
      for atom <- [:invalid_session_key, :invalid_api_key, :authentication_failed] do
        assert ErrorResponse.retry_delay(atom) == nil,
               "expected #{atom} to have no retry delay"
      end
    end

    test "struct-based retry_delay_seconds/1 returns the delay in seconds" do
      assert ErrorResponse.retry_delay_seconds(ErrorResponse.new(29, "")) == 60
      assert ErrorResponse.retry_delay_seconds(ErrorResponse.new(11, "")) == 30
      assert ErrorResponse.retry_delay_seconds(ErrorResponse.new(16, "")) == 5
    end

    test "struct-based retry_delay_seconds/1 falls back to 30 s for non-retryable atoms" do
      assert ErrorResponse.retry_delay_seconds(ErrorResponse.new(9, "")) == 30
    end
  end

  describe "retryable?/1 (struct-based)" do
    test "agrees with retryable_error?/1" do
      assert ErrorResponse.retryable?(ErrorResponse.new(29, ""))
      refute ErrorResponse.retryable?(ErrorResponse.new(9, ""))
    end
  end
end
