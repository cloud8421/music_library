defmodule MusicLibrary.Logger.SingleLineFormatterTest do
  use ExUnit.Case, async: true

  alias MusicLibrary.Logger.SingleLineFormatter

  @ts {{2024, 1, 15}, {14, 30, 45, 123}}

  describe "environment configuration" do
    test "single_line_logging is disabled in dev/test" do
      refute Application.fetch_env!(:music_library, :single_line_logging)
    end

    test "default formatter is the standard pattern (not our custom module)" do
      default_formatter = Application.get_env(:logger, :default_formatter, [])

      refute match?({MusicLibrary.Logger.SingleLineFormatter, _}, default_formatter[:format])
      assert is_binary(default_formatter[:format])
    end

    test "Phoenix.Logger is not disabled in dev/test" do
      phoenix_logger = Application.get_env(:phoenix, :logger, true)
      assert phoenix_logger
    end
  end

  describe "format/4" do
    test "replaces embedded newlines with escaped \\n" do
      result =
        SingleLineFormatter.format(:error, "line1\nline2\nline3", @ts, [])
        |> IO.chardata_to_string()

      assert result =~ "line1\\nline2\\nline3"
      refute String.contains?(result, "\nline2")
      assert String.ends_with?(result, "\n")
    end

    test "messages without newlines pass through unchanged" do
      result =
        SingleLineFormatter.format(:info, "hello world", @ts, [])
        |> IO.chardata_to_string()

      assert result =~ "hello world"
      assert String.ends_with?(result, "\n")
    end

    test "handles iolist input" do
      iolist = ~c"hello\nworld"

      result =
        SingleLineFormatter.format(:error, iolist, @ts, [])
        |> IO.chardata_to_string()

      assert result =~ "hello\\nworld"
      assert String.ends_with?(result, "\n")
    end

    test "preserves metadata in output" do
      result =
        SingleLineFormatter.format(:info, "test message", @ts, request_id: "abc123")
        |> IO.chardata_to_string()

      assert result =~ "request_id=abc123"
    end

    test "handles empty messages" do
      result =
        SingleLineFormatter.format(:info, "", @ts, [])
        |> IO.chardata_to_string()

      assert String.ends_with?(result, "\n")
      assert result =~ "[info]"
    end

    test "handles nil metadata" do
      result =
        SingleLineFormatter.format(:info, "msg", @ts, [])
        |> IO.chardata_to_string()

      assert result =~ "[info] msg"
    end

    test "output is a single line (no unescaped newlines in the message part)" do
      result =
        SingleLineFormatter.format(:error, "a\nb\nc", @ts, [])
        |> IO.chardata_to_string()

      lines = String.split(result, "\n", trim: true)
      assert length(lines) == 1
    end

    test "includes level and timestamp" do
      result =
        SingleLineFormatter.format(:warning, "caution", @ts, [])
        |> IO.chardata_to_string()

      assert result =~ "[warning]"
      assert result =~ "14:30:45.123"
    end

    test "handles multiple metadata keys" do
      result =
        SingleLineFormatter.format(:info, "msg", @ts, request_id: "req1", pid: self())
        |> IO.chardata_to_string()

      assert result =~ "request_id=req1"
    end

    test "pipe character in message is preserved" do
      result =
        SingleLineFormatter.format(:info, "status=200|duration=10ms", @ts, [])
        |> IO.chardata_to_string()

      assert result =~ "status=200|duration=10ms"
    end

    test "handles non-binary, non-list message via inspect fallback" do
      result =
        SingleLineFormatter.format(:info, %{key: "value"}, @ts, [])
        |> IO.chardata_to_string()

      assert result =~ "%{key: \"value\"}"
    end

    test "handles invalid iolist gracefully (UnicodeConversionError)" do
      # Surrogate codepoint 0xD800 is not valid Unicode
      result =
        SingleLineFormatter.format(:error, [0xD800], @ts, [])
        |> IO.chardata_to_string()

      assert result =~ "[error]"
      assert String.ends_with?(result, "\n")
    end

    test "unknown metadata keys are included via inspect" do
      result =
        SingleLineFormatter.format(:info, "msg", @ts, custom_key: "custom_val")
        |> IO.chardata_to_string()

      assert result =~ "custom_key="
      assert result =~ "custom_val"
    end
  end
end
