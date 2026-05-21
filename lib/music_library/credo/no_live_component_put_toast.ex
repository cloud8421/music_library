if Code.ensure_loaded?(Credo) do
  defmodule MusicLibrary.Credo.NoLiveComponentPutToast do
    @moduledoc false

    use Credo.Check,
      base_priority: :high,
      category: :warning,
      explanations: [
        check: """
        LiveComponents should use `put_toast!/2`, not `put_toast/3`.

        `put_toast!/2` sends the toast request to the parent LiveView, whose
        `ShowToast` hook owns the socket update. Calling `put_toast/3` directly
        inside a LiveComponent mutates the component socket instead.
        """
      ]

    @message "Use `put_toast!/2` instead of `put_toast/3` in LiveComponents."

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
        if live_component_body?(body) do
          issues ++ collect_put_toast_issues(body, issue_meta)
        else
          issues
        end

      {ast, issues}
    end

    defp traverse_module(ast, issues, _issue_meta), do: {ast, issues}

    defp live_component_body?(body) do
      Credo.Code.prewalk(body, &traverse_live_component_use/2, false)
    end

    defp traverse_live_component_use({:defmodule, _meta, _args}, found?), do: {nil, found?}

    defp traverse_live_component_use(
           {:use, _meta, [{:__aliases__, _alias_meta, [:MusicLibraryWeb]}, :live_component]} = ast,
           _found?
         ) do
      {ast, true}
    end

    defp traverse_live_component_use(
           {:use, _meta, [{:__aliases__, _alias_meta, [:Phoenix, :LiveComponent]}]} = ast,
           _found?
         ) do
      {ast, true}
    end

    defp traverse_live_component_use(ast, found?), do: {ast, found?}

    defp collect_put_toast_issues(body, issue_meta) do
      Credo.Code.prewalk(body, &traverse_put_toast_call(&1, &2, issue_meta))
    end

    defp traverse_put_toast_call({:defmodule, _meta, _args}, issues, _issue_meta),
      do: {nil, issues}

    defp traverse_put_toast_call({:put_toast, meta, args} = ast, issues, issue_meta)
         when is_list(args) and length(args) == 3 do
      {ast, issues ++ [issue_for(meta, issue_meta)]}
    end

    defp traverse_put_toast_call(
           {{:., dot_meta, [_target, :put_toast]}, call_meta, args} = ast,
           issues,
           issue_meta
         )
         when is_list(args) and length(args) == 3 do
      {ast, issues ++ [issue_for(call_meta, dot_meta, issue_meta)]}
    end

    defp traverse_put_toast_call({:|>, _meta, [_piped_value, call]} = ast, issues, issue_meta) do
      case piped_put_toast_meta(call) do
        nil -> {ast, issues}
        meta -> {ast, issues ++ [issue_for(meta, issue_meta)]}
      end
    end

    defp traverse_put_toast_call(
           {:&, _capture_meta, [{:/, _arity_meta, [{:put_toast, meta, nil}, 3]}]} = ast,
           issues,
           issue_meta
         ) do
      {ast, issues ++ [issue_for(meta, issue_meta)]}
    end

    defp traverse_put_toast_call(
           {:&, _capture_meta,
            [
              {:/, _arity_meta, [{{:., dot_meta, [_target, :put_toast]}, call_meta, _args}, 3]}
            ]} = ast,
           issues,
           issue_meta
         ) do
      {ast, issues ++ [issue_for(call_meta, dot_meta, issue_meta)]}
    end

    defp traverse_put_toast_call(ast, issues, _issue_meta), do: {ast, issues}

    defp piped_put_toast_meta({:put_toast, meta, args}) when is_list(args) and length(args) == 2,
      do: meta

    defp piped_put_toast_meta({{:., dot_meta, [_target, :put_toast]}, call_meta, args})
         when is_list(args) and length(args) == 2 do
      merge_meta(call_meta, dot_meta)
    end

    defp piped_put_toast_meta(_call), do: nil

    defp issue_for(meta, issue_meta) do
      format_issue(
        issue_meta,
        message: @message,
        trigger: "put_toast",
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
