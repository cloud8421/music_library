if Code.ensure_loaded?(Credo) do
  defmodule MusicLibrary.Credo.NoPutToastBangInLiveView do
    @moduledoc false

    use Credo.Check,
      base_priority: :high,
      category: :warning,
      explanations: [
        check: """
        LiveViews should use `put_toast/3` (imported from LiveToast), not
        `put_toast!/2` (imported from MusicLibraryWeb.Hooks.ShowToast).

        `put_toast!/2` is designed for LiveComponents and sends the toast
        request to the parent LiveView. Calling it directly inside a LiveView
        bypasses the socket update that the LiveView controls.

        Use `put_toast(socket, :info, "message")` with 3 arguments instead.
        """
      ]

    @message "Use `put_toast(socket, type, msg)` instead of `put_toast!/2` in LiveViews."

    def run(source_file, params \\ []) do
      issue_meta = IssueMeta.for(source_file, params)

      Credo.Code.prewalk(source_file, &traverse_module(&1, &2, issue_meta))
    end

    defp traverse_module(
           {:defmodule, _meta, [_module_name, [do: body]]} = ast,
           issues,
           issue_meta
         ) do
      issues =
        if live_view_body?(body) do
          issues ++ collect_put_toast_bang_issues(body, issue_meta)
        else
          issues
        end

      {ast, issues}
    end

    defp traverse_module(ast, issues, _issue_meta), do: {ast, issues}

    defp live_view_body?(body) do
      Credo.Code.prewalk(body, &traverse_live_view_use/2, false)
    end

    defp traverse_live_view_use({:defmodule, _meta, _args}, found?), do: {nil, found?}

    defp traverse_live_view_use(
           {:use, _meta, [{:__aliases__, _alias_meta, [:MusicLibraryWeb]}, :live_view]} = ast,
           _found?
         ) do
      {ast, true}
    end

    defp traverse_live_view_use(ast, found?), do: {ast, found?}

    defp collect_put_toast_bang_issues(body, issue_meta) do
      Credo.Code.prewalk(body, &traverse_put_toast_bang_call(&1, &2, issue_meta))
    end

    defp traverse_put_toast_bang_call({:defmodule, _meta, _args}, issues, _issue_meta),
      do: {nil, issues}

    # Direct call: put_toast!(kind, msg)
    defp traverse_put_toast_bang_call(
           {:put_toast!, meta, [_kind, _msg]} = ast,
           issues,
           issue_meta
         ) do
      {ast, issues ++ [issue_for(meta, issue_meta)]}
    end

    # Module-qualified: SomeMod.put_toast!(kind, msg)
    defp traverse_put_toast_bang_call(
           {{:., dot_meta, [_target, :put_toast!]}, call_meta, [_kind, _msg]} = ast,
           issues,
           issue_meta
         ) do
      {ast, issues ++ [issue_for(call_meta, dot_meta, issue_meta)]}
    end

    # Pipe: lhs |> put_toast!(kind, msg)
    defp traverse_put_toast_bang_call(
           {:|>, _pipe_meta, [_lhs, {:put_toast!, _, [_kind, _msg]} = call]} = ast,
           issues,
           issue_meta
         ) do
      meta = piped_call_meta(call)
      {ast, issues ++ [issue_for(meta, issue_meta)]}
    end

    # Capture: &put_toast!/2
    defp traverse_put_toast_bang_call(
           {:&, _capture_meta, [{:/, _arity_meta, [{:put_toast!, meta, nil}, 2]}]} = ast,
           issues,
           issue_meta
         ) do
      {ast, issues ++ [issue_for(meta, issue_meta)]}
    end

    # Capture mod-qualified: &SomeMod.put_toast!/2
    defp traverse_put_toast_bang_call(
           {:&, _capture_meta,
            [
              {:/, _arity_meta,
               [
                 {{:., dot_meta, [_target, :put_toast!]}, call_meta, _args},
                 2
               ]}
            ]} = ast,
           issues,
           issue_meta
         ) do
      {ast, issues ++ [issue_for(call_meta, dot_meta, issue_meta)]}
    end

    defp traverse_put_toast_bang_call(ast, issues, _issue_meta), do: {ast, issues}

    defp piped_call_meta({:put_toast!, meta, _args}), do: meta

    defp issue_for(meta, issue_meta) do
      format_issue(
        issue_meta,
        message: @message,
        trigger: "put_toast!",
        line_no: meta[:line],
        column: meta[:column]
      )
    end

    defp issue_for(call_meta, dot_meta, issue_meta) do
      issue_for(merge_meta(call_meta, dot_meta), issue_meta)
    end

    defp merge_meta(call_meta, dot_meta) do
      [
        line: call_meta[:line] || dot_meta[:line],
        column: call_meta[:column] || dot_meta[:column]
      ]
    end
  end
end
