defmodule Wikipedia.APITest do
  use ExUnit.Case, async: true

  alias Wikipedia.API
  alias Wikipedia.API.ErrorResponse

  @config %Wikipedia.Config{
    user_agent: "test_agent",
    req_options: [plug: {Req.Test, Wikipedia.API}, max_retries: 0],
    api_cooldown: 0
  }

  describe "Action API silent-bug fix (HTTP 200 + body error envelope)" do
    @tag :capture_log
    test "promotes ratelimited Action API error into a retryable ErrorResponse" do
      Req.Test.stub(API, fn conn ->
        Req.Test.json(conn, %{
          "error" => %{"code" => "ratelimited", "info" => "You've exceeded your rate limit."}
        })
      end)

      assert {:error, %ErrorResponse{} = err} = API.get_wikipedia_title("Q352766", @config)
      assert err.status == 200
      assert err.code == "ratelimited"
      assert err.kind == :rate_limit
      assert ErrorResponse.retryable?(err)
    end

    @tag :capture_log
    test "promotes maxlag Action API error into a retryable ErrorResponse" do
      Req.Test.stub(API, fn conn ->
        Req.Test.json(conn, %{
          "error" => %{
            "code" => "maxlag",
            "info" => "Waiting for a database server: 7 seconds lagged."
          }
        })
      end)

      assert {:error, %ErrorResponse{kind: :rate_limit} = err} =
               API.get_wikipedia_title("Q352766", @config)

      assert err.code == "maxlag"
      assert ErrorResponse.retryable?(err)
    end

    @tag :capture_log
    test "promotes readonly Action API error into a retryable server error" do
      Req.Test.stub(API, fn conn ->
        Req.Test.json(conn, %{
          "error" => %{"code" => "readonly", "info" => "The wiki is currently in read-only mode."}
        })
      end)

      assert {:error, %ErrorResponse{kind: :server_error} = err} =
               API.get_wikipedia_title("Q352766", @config)

      assert ErrorResponse.retryable?(err)
    end

    @tag :capture_log
    test "promotes internal_api_error_* codes into retryable server errors" do
      Req.Test.stub(API, fn conn ->
        Req.Test.json(conn, %{
          "error" => %{
            "code" => "internal_api_error_DBQueryError",
            "info" => "[abc] Exception Caught"
          }
        })
      end)

      assert {:error, %ErrorResponse{kind: :server_error} = err} =
               API.get_wikipedia_title("Q352766", @config)

      assert ErrorResponse.retryable?(err)
    end

    @tag :capture_log
    test "classifies unknown error codes as non-retryable client errors" do
      Req.Test.stub(API, fn conn ->
        Req.Test.json(conn, %{
          "error" => %{"code" => "badtoken", "info" => "Invalid CSRF token."}
        })
      end)

      assert {:error, %ErrorResponse{kind: :client_error} = err} =
               API.get_wikipedia_title("Q352766", @config)

      refute ErrorResponse.retryable?(err)
    end
  end

  describe "Action API non-error body shapes still return {:ok, _}" do
    test "wbgetentities with a missing entity returns {:ok, body} — not an error" do
      Req.Test.stub(API, fn conn ->
        Req.Test.json(conn, %{
          "entities" => %{"Q99999999999" => %{"id" => "Q99999999999", "missing" => ""}}
        })
      end)

      assert {:ok, nil} = API.get_wikipedia_title("Q99999999999", @config)
    end

    test "wbgetentities with no enwiki sitelink returns {:ok, nil}" do
      Req.Test.stub(API, fn conn ->
        Req.Test.json(conn, %{
          "entities" => %{"Q352766" => %{"id" => "Q352766", "sitelinks" => %{}}}
        })
      end)

      assert {:ok, nil} = API.get_wikipedia_title("Q352766", @config)
    end

    test "query with empty extract returns {:ok, nil}" do
      Req.Test.stub(API, fn conn ->
        Req.Test.json(conn, %{
          "query" => %{
            "pages" => %{"123" => %{"pageid" => 123, "title" => "X", "extract" => nil}}
          }
        })
      end)

      assert {:ok, nil} = API.get_article_extract("X", @config)
    end
  end

  describe "REST v1 API error classification" do
    @tag :capture_log
    test "404 on article summary surfaces as a not-found ErrorResponse" do
      Req.Test.stub(API, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{
          "httpCode" => 404,
          "httpReason" => "Not Found",
          "messageTranslations" => %{"en" => "The specified title does not exist."}
        })
      end)

      assert {:error, %ErrorResponse{status: 404, kind: :not_found} = err} =
               API.get_article_summary("Missing%20Title", @config)

      refute ErrorResponse.retryable?(err)
    end

    @tag :capture_log
    test "429 on article summary surfaces as a retryable rate-limit ErrorResponse" do
      Req.Test.stub(API, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{
          "httpCode" => 429,
          "httpReason" => "Too Many Requests",
          "messageTranslations" => %{"en" => "Slow down."}
        })
      end)

      assert {:error, %ErrorResponse{status: 429, kind: :rate_limit} = err} =
               API.get_article_summary("Steven%20Wilson", @config)

      assert ErrorResponse.retryable?(err)
    end
  end
end
