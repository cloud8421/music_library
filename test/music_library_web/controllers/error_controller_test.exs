defmodule MusicLibraryWeb.ErrorControllerTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.ErrorsFixtures

  defp api_token do
    Application.get_env(:music_library, MusicLibraryWeb)
    |> Keyword.fetch!(:api_token)
  end

  describe "authentication" do
    test "GET /api/v1/errors requires a bearer token", %{conn: conn} do
      assert get(conn, ~p"/api/v1/errors").status == 401
    end

    test "GET /api/v1/errors/:id requires a bearer token", %{conn: conn} do
      assert get(conn, ~p"/api/v1/errors/1").status == 401
    end
  end

  describe "GET /api/v1/errors" do
    setup do
      error1 =
        error_fixture(%{
          reason: "First error",
          source_line: "lib/my_module.ex:10",
          source_function: "MyModule.do_thing/0",
          fingerprint:
            error_fingerprint(:runtime_error, "lib/my_module.ex:10", "MyModule.do_thing/0")
        })

      error2 =
        error_fixture(%{
          reason: "Second error",
          status: :resolved,
          muted: true,
          source_line: "lib/my_module.ex:20",
          source_function: "MyModule.other_thing/1",
          fingerprint:
            error_fingerprint(:runtime_error, "lib/my_module.ex:20", "MyModule.other_thing/1")
        })

      error3 =
        error_fixture(%{
          kind: "ArgumentError",
          reason: "Bad argument in MyOtherModule.call/2",
          source_line: "lib/other_module.ex:10",
          source_function: "MyOtherModule.call/2",
          fingerprint:
            error_fingerprint(:argument_error, "lib/other_module.ex:10", "MyOtherModule.call/2")
        })

      %{errors: [error1, error2, error3]}
    end

    test "returns a paginated list of errors", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/errors")

      assert %{"errors" => returned, "total" => 3, "limit" => 50, "offset" => 0} =
               json_response(conn, 200)

      assert length(returned) == 3

      # Verify each returned error has the expected fields
      for error <- returned do
        assert is_integer(error["id"])
        assert is_binary(error["kind"])
        assert is_binary(error["reason"])
        assert is_binary(error["source_line"])
        assert is_binary(error["source_function"])
        assert error["status"] in ["resolved", "unresolved"]
        assert is_binary(error["fingerprint"])
        assert is_binary(error["last_occurrence_at"])
        assert is_boolean(error["muted"])
        assert is_binary(error["inserted_at"])
        assert is_binary(error["updated_at"])
        # List endpoint omits occurrence_count and first_occurrence_at
        refute Map.has_key?(error, "occurrence_count")
        refute Map.has_key?(error, "first_occurrence_at")
      end
    end

    test "filters by status", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/errors?status=resolved")

      assert %{"errors" => returned, "total" => 1} = json_response(conn, 200)
      assert Enum.all?(returned, &(&1["status"] == "resolved"))
    end

    test "filters by muted", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/errors?muted=true")

      assert %{"errors" => returned, "total" => 1} = json_response(conn, 200)
      assert Enum.all?(returned, &(&1["muted"] == true))
    end

    test "filters by search on reason", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/errors?search=second")

      assert %{"errors" => returned, "total" => 1} = json_response(conn, 200)
      assert hd(returned)["reason"] == "Second error"
    end

    test "respects limit and offset", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/errors?limit=2&offset=1")

      assert %{"errors" => returned, "total" => 3, "limit" => 2, "offset" => 1} =
               json_response(conn, 200)

      assert length(returned) == 2
    end

    test "returns empty list when no errors match", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/errors?search=NONEXISTENT")

      assert %{"errors" => [], "total" => 0} = json_response(conn, 200)
    end

    test "clamps negative limit to 1", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/errors?limit=-1")

      assert %{"errors" => returned, "limit" => 1} = json_response(conn, 200)
      assert returned != []
    end

    test "clamps negative offset to 0", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/errors?offset=-5")

      assert %{"offset" => 0} = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/errors/:id" do
    setup do
      error = error_fixture(%{reason: "Something went wrong"})
      occ1 = occurrence_fixture(error, %{breadcrumbs: ["first occurrence"]})

      occ2 =
        occurrence_fixture(error, %{
          reason: "Updated reason",
          context: %{user_id: 2},
          breadcrumbs: ["second occurrence"],
          stacktrace: %ErrorTracker.Stacktrace{
            lines: [
              %ErrorTracker.Stacktrace.Line{
                application: "music_library",
                module: "OtherModule",
                function: "call",
                arity: 2,
                file: "lib/other_module.ex",
                line: 10
              },
              %ErrorTracker.Stacktrace.Line{
                application: "elixir",
                module: "Enum",
                function: "map",
                arity: 2,
                file: "lib/enum.ex",
                line: 1500
              }
            ]
          }
        })

      %{error: error, occurrences: [occ1, occ2]}
    end

    test "returns a single error with occurrences", %{conn: conn, error: error} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/errors/#{error.id}")

      assert %{"error" => returned} = json_response(conn, 200)

      assert returned["id"] == error.id
      assert returned["reason"] == "Something went wrong"
      assert returned["status"] == "unresolved"
      assert returned["muted"] == false

      # Computed fields
      assert returned["occurrence_count"] == 2
      refute is_nil(returned["first_occurrence_at"])

      # Occurrences
      occurrences = returned["occurrences"]
      assert length(occurrences) == 2

      # Most recent first (desc inserted_at)
      first_occ = hd(occurrences)
      second_occ = List.last(occurrences)

      assert first_occ["reason"] == "Updated reason"
      assert first_occ["context"] == %{"user_id" => 2}
      assert first_occ["breadcrumbs"] == ["second occurrence"]

      assert second_occ["reason"] == "Something went wrong"
      assert second_occ["context"] == %{"user_id" => 1}
      assert second_occ["breadcrumbs"] == ["first occurrence"]

      # Stacktrace lines
      lines = first_occ["stacktrace"]["lines"]
      assert length(lines) == 2
      [line1, line2] = lines

      assert line1["module"] == "OtherModule"
      assert line1["function"] == "call"
      assert line1["arity"] == 2
      assert line1["file"] == "lib/other_module.ex"
      assert line1["line"] == 10

      assert line2["module"] == "Enum"
      assert line2["application"] == "elixir"
    end

    test "returns 404 for non-existent error", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/errors/99999")

      assert json_response(conn, 404) == %{"error" => "Not Found"}
    end

    test "returns 404 for non-integer id instead of crashing", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/errors/not-an-id")

      assert json_response(conn, 404) == %{"error" => "Not Found"}
    end
  end
end
