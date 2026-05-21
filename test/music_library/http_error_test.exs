defmodule MusicLibrary.HttpErrorTest do
  use ExUnit.Case, async: true

  alias MusicLibrary.HttpError

  describe "default_kind/1" do
    test "maps 429 to :rate_limit" do
      assert HttpError.default_kind(429) == :rate_limit
    end

    test "maps 5xx to :server_error" do
      for status <- [500, 502, 503, 504, 599] do
        assert HttpError.default_kind(status) == :server_error,
               "expected #{status} to be :server_error"
      end
    end

    test "maps 401 and 403 to :auth_error" do
      assert HttpError.default_kind(401) == :auth_error
      assert HttpError.default_kind(403) == :auth_error
    end

    test "maps 404 to :not_found" do
      assert HttpError.default_kind(404) == :not_found
    end

    test "maps other 4xx to :client_error" do
      for status <- [400, 402, 405, 422, 499] do
        assert HttpError.default_kind(status) == :client_error,
               "expected #{status} to be :client_error"
      end
    end

    test "maps unexpected statuses to :unknown" do
      for status <- [200, 302, 600, 999] do
        assert HttpError.default_kind(status) == :unknown,
               "expected #{status} to be :unknown"
      end
    end
  end
end
