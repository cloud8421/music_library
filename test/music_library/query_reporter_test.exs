defmodule MusicLibrary.QueryReporterTest do
  use ExUnit.Case, async: false

  alias MusicLibrary.QueryReporter

  @event [:music_library, :repo, :query]

  setup do
    path =
      Path.join(
        System.tmp_dir!(),
        "query_reporter_test_#{System.unique_integer([:positive])}.sql"
      )

    on_exit(fn ->
      QueryReporter.stop()
      File.rm(path)
    end)

    %{path: path}
  end

  describe "start/1" do
    test "creates the output file with a header", %{path: path} do
      QueryReporter.start(path)

      content = File.read!(path)
      assert content =~ "-- Query Reporter started at"
    end

    test "truncates existing file on restart", %{path: path} do
      File.write!(path, "old content\n")

      QueryReporter.start(path)

      content = File.read!(path)
      refute content =~ "old content"
      assert content =~ "-- Query Reporter started at"
    end

    test "attaches a telemetry handler", %{path: path} do
      QueryReporter.start(path)

      handlers = :telemetry.list_handlers(@event)
      assert Enum.any?(handlers, &(&1.id == "music-library-query-reporter"))
    end

    test "restarts cleanly when already running", %{path: path} do
      QueryReporter.start(path)

      new_path = path <> ".new"

      on_exit(fn -> File.rm(new_path) end)

      QueryReporter.start(new_path)

      assert File.exists?(new_path)

      handlers = :telemetry.list_handlers(@event)
      matching = Enum.filter(handlers, &(&1.id == "music-library-query-reporter"))
      assert length(matching) == 1
    end
  end

  describe "stop/0" do
    test "detaches the telemetry handler", %{path: path} do
      QueryReporter.start(path)
      assert :ok = QueryReporter.stop()

      handlers = :telemetry.list_handlers(@event)
      refute Enum.any?(handlers, &(&1.id == "music-library-query-reporter"))
    end

    test "returns error when not running" do
      assert {:error, "Query reporter is not running"} = QueryReporter.stop()
    end
  end

  describe "handle_event/4" do
    test "appends a formatted query entry to the file", %{path: path} do
      QueryReporter.start(path)

      metadata = %{
        query: "SELECT * FROM records WHERE id = ?",
        cast_params: [1],
        params: [1],
        stacktrace: []
      }

      measurements = %{total_time: 1_000_000, query_time: 800_000}

      QueryReporter.handle_event(@event, measurements, metadata, path)

      content = File.read!(path)
      assert content =~ "SELECT * FROM records WHERE id = 1;"
    end

    test "writes timing metadata", %{path: path} do
      QueryReporter.start(path)

      metadata = %{query: "SELECT 1", cast_params: [], params: [], stacktrace: []}
      measurements = %{total_time: 2_000_000, query_time: 1_500_000, queue_time: 300_000}

      QueryReporter.handle_event(@event, measurements, metadata, path)

      content = File.read!(path)
      assert content =~ "-- total="
      assert content =~ "db="
      assert content =~ "queue="
    end

    test "omits missing timing keys", %{path: path} do
      QueryReporter.start(path)

      metadata = %{query: "SELECT 1", cast_params: [], params: [], stacktrace: []}
      measurements = %{total_time: 1_000_000}

      QueryReporter.handle_event(@event, measurements, metadata, path)

      content = File.read!(path)
      assert content =~ "total="
      refute content =~ "db="
      refute content =~ "queue="
      refute content =~ "decode="
    end

    @tag :capture_log
    test "logs a warning and does not raise on write failure" do
      metadata = %{query: "SELECT 1", cast_params: [], params: [], stacktrace: []}
      measurements = %{total_time: 1_000_000}

      QueryReporter.handle_event(@event, measurements, metadata, "/nonexistent/dir/file.sql")
    end
  end

  describe "query interpolation" do
    test "interpolates integer params", %{path: path} do
      QueryReporter.start(path)
      emit_query(path, "SELECT * FROM records WHERE id = ?", [42])

      assert File.read!(path) =~ "WHERE id = 42;"
    end

    test "interpolates float params", %{path: path} do
      QueryReporter.start(path)
      emit_query(path, "SELECT * FROM records WHERE score > ?", [3.14])

      assert File.read!(path) =~ "WHERE score > 3.14;"
    end

    test "interpolates nil as NULL", %{path: path} do
      QueryReporter.start(path)
      emit_query(path, "SELECT * FROM records WHERE deleted_at = ?", [nil])

      assert File.read!(path) =~ "WHERE deleted_at = NULL;"
    end

    test "interpolates boolean true as 1", %{path: path} do
      QueryReporter.start(path)
      emit_query(path, "SELECT * FROM records WHERE active = ?", [true])

      assert File.read!(path) =~ "WHERE active = 1;"
    end

    test "interpolates boolean false as 0", %{path: path} do
      QueryReporter.start(path)
      emit_query(path, "SELECT * FROM records WHERE active = ?", [false])

      assert File.read!(path) =~ "WHERE active = 0;"
    end

    test "interpolates string params with single-quote escaping", %{path: path} do
      QueryReporter.start(path)
      emit_query(path, "SELECT * FROM records WHERE title = ?", ["Rock'n'Roll"])

      assert File.read!(path) =~ "WHERE title = 'Rock''n''Roll';"
    end

    test "interpolates binary data as hex", %{path: path} do
      QueryReporter.start(path)
      emit_query(path, "SELECT * FROM records WHERE hash = ?", [<<0xDE, 0xAD, 0xBE, 0xEF>>])

      assert File.read!(path) =~ "WHERE hash = X'DEADBEEF';"
    end

    test "interpolates multiple params", %{path: path} do
      QueryReporter.start(path)
      emit_query(path, "INSERT INTO records (title, year) VALUES (?, ?)", ["Album", 2024])

      content = File.read!(path)
      assert content =~ "VALUES ('Album', 2024);"
    end

    test "leaves query unchanged when params list is empty", %{path: path} do
      QueryReporter.start(path)
      emit_query(path, "SELECT count(*) FROM records", [])

      assert File.read!(path) =~ "SELECT count(*) FROM records;"
    end

    test "interpolates map params as JSON", %{path: path} do
      QueryReporter.start(path)

      emit_query(
        path,
        "UPDATE artist_infos SET musicbrainz_data = ? WHERE id = ?",
        [%{"name" => "Test Artist"}, "abc"]
      )

      assert File.read!(path) =~ ~s|SET musicbrainz_data = '{"name":"Test Artist"}'|
    end

    test "interpolates list params as JSON", %{path: path} do
      QueryReporter.start(path)
      emit_query(path, "UPDATE records SET genres = ?", [["rock", "pop"]])

      assert File.read!(path) =~ ~s|SET genres = '["rock","pop"]'|
    end

    test "interpolates list of embedded maps as JSON", %{path: path} do
      QueryReporter.start(path)

      emit_query(
        path,
        "UPDATE records SET artists = ?",
        [[%{"name" => "A"}, %{"name" => "B"}]]
      )

      assert File.read!(path) =~ ~s|SET artists = '[{"name":"A"},{"name":"B"}]'|
    end

    test "escapes single quotes in map JSON params", %{path: path} do
      QueryReporter.start(path)
      emit_query(path, "UPDATE records SET data = ?", [%{"title" => "Rock'n'Roll"}])

      assert File.read!(path) =~ ~s|SET data = '{"title":"Rock''n''Roll"}'|
    end

    test "uses cast_params over params when both present", %{path: path} do
      QueryReporter.start(path)

      metadata = %{
        query: "SELECT * FROM records WHERE id = ?",
        cast_params: [99],
        params: [1],
        stacktrace: []
      }

      QueryReporter.handle_event(@event, %{total_time: 1_000_000}, metadata, path)

      assert File.read!(path) =~ "WHERE id = 99;"
    end

    test "falls back to params when cast_params is nil", %{path: path} do
      QueryReporter.start(path)

      metadata = %{
        query: "SELECT * FROM records WHERE id = ?",
        cast_params: nil,
        params: [7],
        stacktrace: []
      }

      QueryReporter.handle_event(@event, %{total_time: 1_000_000}, metadata, path)

      assert File.read!(path) =~ "WHERE id = 7;"
    end
  end

  describe "source location" do
    test "includes source location from stacktrace", %{path: path} do
      QueryReporter.start(path)

      stacktrace = [{__MODULE__, :test_function, 2, [file: ~c"test/my_test.exs", line: 42]}]

      metadata = %{query: "SELECT 1", cast_params: [], params: [], stacktrace: stacktrace}

      QueryReporter.handle_event(@event, %{total_time: 1_000_000}, metadata, path)

      content = File.read!(path)
      assert content =~ "-- MusicLibrary.QueryReporterTest.test_function/2"
      assert content =~ "test/my_test.exs:42"
    end

    test "omits location comment when stacktrace is nil", %{path: path} do
      QueryReporter.start(path)

      metadata = %{query: "SELECT 1", cast_params: [], params: [], stacktrace: nil}

      QueryReporter.handle_event(@event, %{total_time: 1_000_000}, metadata, path)

      content = File.read!(path)
      lines = content |> String.split("\n") |> Enum.reject(&(&1 == ""))

      # Should only have the header, timing, and query — no location line
      refute Enum.any?(lines, &String.contains?(&1, "at:"))
    end

    test "omits location comment when stacktrace is empty", %{path: path} do
      QueryReporter.start(path)

      metadata = %{query: "SELECT 1", cast_params: [], params: [], stacktrace: []}

      QueryReporter.handle_event(@event, %{total_time: 1_000_000}, metadata, path)

      content = File.read!(path)
      lines = content |> String.split("\n") |> Enum.reject(&(&1 == ""))
      refute Enum.any?(lines, &String.contains?(&1, "at:"))
    end
  end

  defp emit_query(path, query, params) do
    metadata = %{query: query, cast_params: params, params: params, stacktrace: []}
    measurements = %{total_time: 1_000_000}
    QueryReporter.handle_event(@event, measurements, metadata, path)
  end
end
