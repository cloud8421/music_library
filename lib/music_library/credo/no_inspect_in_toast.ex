if Code.ensure_loaded?(Credo) do
  defmodule MusicLibrary.Credo.NoInspectInToast do
    @moduledoc false

    use Credo.Check,
      base_priority: :high,
      category: :warning,
      explanations: [
        check: """
        User-facing error reasons must use `ErrorMessages.friendly_message/1`,
        never `inspect(reason)`.

        `inspect(reason)` produces technical output (struct internals, stacktraces)
        that is inappropriate for user-facing toast notifications. Use the
        project's centralized `ErrorMessages.friendly_message/1` to translate
        internal error terms into user-friendly gettext strings.
        """
      ]

    @message "Use `ErrorMessages.friendly_message/1` instead of `inspect/1` in toast messages."

    def run(source_file, params \\ []) do
      issue_meta = IssueMeta.for(source_file, params)

      Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    end

    defp traverse(
           {:put_toast, meta, args} = ast,
           issues,
           issue_meta
         ) do
      issues = issues ++ flag_inspect_in_args(args, meta, issue_meta)
      {ast, issues}
    end

    defp traverse(
           {:put_toast!, meta, args} = ast,
           issues,
           issue_meta
         ) do
      issues = issues ++ flag_inspect_in_args(args, meta, issue_meta)
      {ast, issues}
    end

    # Module-qualified: SomeMod.put_toast(...)
    defp traverse(
           {{:., dot_meta, [_target, :put_toast]}, call_meta, args} = ast,
           issues,
           issue_meta
         ) do
      merged = merge_meta(call_meta, dot_meta)
      issues = issues ++ flag_inspect_in_args(args, merged, issue_meta)
      {ast, issues}
    end

    # Module-qualified: SomeMod.put_toast!(...)
    defp traverse(
           {{:., dot_meta, [_target, :put_toast!]}, call_meta, args} = ast,
           issues,
           issue_meta
         ) do
      merged = merge_meta(call_meta, dot_meta)
      issues = issues ++ flag_inspect_in_args(args, merged, issue_meta)
      {ast, issues}
    end

    # Pipe: lhs |> put_toast(...)
    defp traverse(
           {:|>, pipe_meta, [_lhs, {:put_toast, _, args}]} = ast,
           issues,
           issue_meta
         ) do
      issues = issues ++ flag_inspect_in_args(args, pipe_meta, issue_meta)
      {ast, issues}
    end

    # Pipe: lhs |> put_toast!(...)
    defp traverse(
           {:|>, pipe_meta, [_lhs, {:put_toast!, _, args}]} = ast,
           issues,
           issue_meta
         ) do
      issues = issues ++ flag_inspect_in_args(args, pipe_meta, issue_meta)
      {ast, issues}
    end

    defp traverse(ast, issues, _issue_meta), do: {ast, issues}

    # Check if any argument is or contains an inspect call
    defp flag_inspect_in_args(args, meta, issue_meta) do
      args
      |> Enum.flat_map(&extract_inspect_calls/1)
      |> Enum.map(fn trigger ->
        format_issue(
          issue_meta,
          message: @message,
          trigger: trigger,
          line_no: meta[:line],
          column: meta[:column]
        )
      end)
    end

    # Direct inspect call: inspect(x)
    defp extract_inspect_calls({:inspect, _meta, _args} = ast) do
      [
        ast
        |> Macro.to_string()
        |> String.trim()
      ]
    end

    # Module-qualified: Kernel.inspect(x)
    defp extract_inspect_calls(
           {{:., _, [{:__aliases__, _, [:Kernel]}, :inspect]}, _meta, _args} = ast
         ) do
      [
        ast
        |> Macro.to_string()
        |> String.trim()
      ]
    end

    # String interpolation: "...#{inspect(x)}..."
    defp extract_inspect_calls({:<<>>, _meta, parts}) do
      parts
      |> Enum.flat_map(fn
        {:"::", _, [{:inspect, _, _} = ast, _]} ->
          [Macro.to_string(ast) |> String.trim()]

        {:"::", _, [{{:., _, [{:__aliases__, _, [:Kernel]}, :inspect]}, _, _} = ast, _]} ->
          [Macro.to_string(ast) |> String.trim()]

        _ ->
          []
      end)
    end

    # Pipe: lhs |> inspect()
    defp extract_inspect_calls({:|>, _, [_lhs, {:inspect, _, _args} = rhs]}) do
      [Macro.to_string(rhs) |> String.trim()]
    end

    defp extract_inspect_calls(_), do: []

    defp merge_meta(call_meta, dot_meta) do
      [
        line: call_meta[:line] || dot_meta[:line],
        column: call_meta[:column] || dot_meta[:column]
      ]
    end
  end
end
