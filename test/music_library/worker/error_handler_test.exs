defmodule MusicLibrary.Worker.ErrorHandlerTest do
  use ExUnit.Case, async: true

  alias MusicLibrary.Worker.ErrorHandler

  describe "to_oban_result/1 — successes" do
    test ":ok passes through" do
      assert ErrorHandler.to_oban_result(:ok) == :ok
    end

    test "{:ok, result} passes through unchanged" do
      payload = %{anything: true}
      assert ErrorHandler.to_oban_result({:ok, payload}) == {:ok, payload}
    end
  end

  describe "to_oban_result/1 — retryable ErrorResponses snooze" do
    test "MusicBrainz 503 → {:snooze, 60}" do
      err =
        MusicBrainz.API.ErrorResponse.from_response(%{status: 503, body: %{"error" => "rate"}})

      assert ErrorHandler.to_oban_result({:error, err}) == {:snooze, 60}
    end

    test "parsed retry headers determine the snooze duration" do
      response =
        Req.Response.new(
          status: 503,
          headers: %{"retry-after" => ["42"]},
          body: %{"error" => "rate"}
        )

      err = MusicBrainz.API.ErrorResponse.from_response(response)

      assert ErrorHandler.to_oban_result({:error, err}) == {:snooze, 42}
    end

    test "Discogs 429 → {:snooze, 60}" do
      err = Discogs.API.ErrorResponse.from_response(%{status: 429, body: %{"message" => "rate"}})
      assert ErrorHandler.to_oban_result({:error, err}) == {:snooze, 60}
    end

    test "Wikipedia Action API ratelimited → {:snooze, 30}" do
      err =
        Wikipedia.API.ErrorResponse.from_action_api_body(%{
          "error" => %{"code" => "ratelimited", "info" => "rate"}
        })

      assert ErrorHandler.to_oban_result({:error, err}) == {:snooze, 30}
    end

    test "BraveSearch 500 → {:snooze, 30}" do
      err =
        BraveSearch.API.ErrorResponse.from_response(%{status: 500, body: %{"error" => "boom"}})

      assert ErrorHandler.to_oban_result({:error, err}) == {:snooze, 30}
    end

    test "OpenAI 429 rate_limit_exceeded → {:snooze, 60}" do
      err =
        OpenAI.API.ErrorResponse.from_response(%{
          status: 429,
          body: %{"error" => %{"code" => "rate_limit_exceeded", "message" => "rate"}}
        })

      assert ErrorHandler.to_oban_result({:error, err}) == {:snooze, 60}
    end

    test "Last.fm rate_limit_exceeded → {:snooze, 60}" do
      err = LastFm.API.ErrorResponse.new(29, "Rate limit exceeded")
      assert ErrorHandler.to_oban_result({:error, err}) == {:snooze, 60}
    end
  end

  describe "to_oban_result/1 — non-retryable ErrorResponses cancel" do
    test "MusicBrainz 404 → {:cancel, err}" do
      err = MusicBrainz.API.ErrorResponse.from_response(%{status: 404, body: %{"error" => "nf"}})
      assert {:cancel, ^err} = ErrorHandler.to_oban_result({:error, err})
    end

    test "OpenAI 429 insufficient_quota → {:cancel, err}" do
      err =
        OpenAI.API.ErrorResponse.from_response(%{
          status: 429,
          body: %{"error" => %{"code" => "insufficient_quota", "message" => "quota"}}
        })

      assert {:cancel, ^err} = ErrorHandler.to_oban_result({:error, err})
    end

    test "Last.fm invalid_session_key → {:cancel, err}" do
      err = LastFm.API.ErrorResponse.new(9, "Invalid session key")
      assert {:cancel, ^err} = ErrorHandler.to_oban_result({:error, err})
    end
  end

  describe "to_oban_result/1 — passthrough for unstructured errors and atom reasons" do
    test "unknown {:error, reason} passes through unchanged" do
      assert ErrorHandler.to_oban_result({:error, :something_else}) == {:error, :something_else}
    end

    test "{:cancel, _} passes through unchanged" do
      assert ErrorHandler.to_oban_result({:cancel, :manual}) == {:cancel, :manual}
    end

    test "{:snooze, _} passes through unchanged" do
      assert ErrorHandler.to_oban_result({:snooze, 120}) == {:snooze, 120}
    end
  end
end
