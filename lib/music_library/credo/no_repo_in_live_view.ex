if Code.ensure_loaded?(Credo) do
  defmodule MusicLibrary.Credo.NoRepoInLiveView do
    @moduledoc false

    use Credo.Check,
      base_priority: :high,
      category: :warning,
      explanations: [
        check: """
        LiveViews should never query the database directly. All queries must go
        through context modules (Records, Artists, Collection, Wishlist, etc.).

        Context modules own all queries. Calling Repo directly in a LiveView
        breaks the architectural boundary and makes testing harder.
        """
      ]

    @message "LiveViews should not call Repo directly — delegate to a context module."

    @repo_functions ~w[
      all one get get! get_by get_by! insert insert! insert_all delete delete!
      update update! update_all transaction preload stream aggregate exists?
    ]a

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
          issues ++ collect_repo_call_issues(body, issue_meta)
        else
          issues
        end

      {ast, issues}
    end

    defp traverse_module(ast, issues, _issue_meta), do: {ast, issues}

    # Check if the module body includes `use MusicLibraryWeb, :live_view`
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

    # Collect all direct Repo function calls within the module body
    defp collect_repo_call_issues(body, issue_meta) do
      Credo.Code.prewalk(body, &traverse_repo_call(&1, &2, issue_meta))
    end

    defp traverse_repo_call({:defmodule, _meta, _args}, issues, _issue_meta),
      do: {nil, issues}

    # Match: Repo.function(...)
    defp traverse_repo_call(
           {{:., dot_meta, [{:__aliases__, _alias_meta, [:Repo]}, function]}, call_meta, _args} =
             ast,
           issues,
           issue_meta
         ) do
      if function in @repo_functions do
        {ast, issues ++ [issue_for(call_meta, dot_meta, "Repo.#{function}", issue_meta)]}
      else
        {ast, issues}
      end
    end

    # Match: MusicLibrary.Repo.function(...)
    defp traverse_repo_call(
           {{:., dot_meta, [{:__aliases__, _alias_meta, [:MusicLibrary, :Repo]}, function]},
            call_meta, _args} = ast,
           issues,
           issue_meta
         ) do
      if function in @repo_functions do
        {ast,
         issues ++ [issue_for(call_meta, dot_meta, "MusicLibrary.Repo.#{function}", issue_meta)]}
      else
        {ast, issues}
      end
    end

    # Match: pipe |> Repo.function()
    defp traverse_repo_call(
           {:|>, _pipe_meta,
            [_lhs, {{:., _, [{:__aliases__, _, [:Repo]}, function]}, _, _} = _rhs]} =
             ast,
           issues,
           issue_meta
         ) do
      if function in @repo_functions do
        # Extract column from the RHS function call
        meta = call_meta_from_pipe(ast)
        {ast, issues ++ [issue_for(meta, meta, "Repo.#{function}", issue_meta)]}
      else
        {ast, issues}
      end
    end

    # Match: pipe |> MusicLibrary.Repo.function()
    defp traverse_repo_call(
           {:|>, _pipe_meta,
            [
              _lhs,
              {{:., _, [{:__aliases__, _, [:MusicLibrary, :Repo]}, function]}, _, _} = _rhs
            ]} = ast,
           issues,
           issue_meta
         ) do
      if function in @repo_functions do
        meta = call_meta_from_pipe(ast)
        {ast, issues ++ [issue_for(meta, meta, "MusicLibrary.Repo.#{function}", issue_meta)]}
      else
        {ast, issues}
      end
    end

    defp traverse_repo_call(ast, issues, _issue_meta), do: {ast, issues}

    defp call_meta_from_pipe({:|>, meta, _}), do: meta

    defp issue_for(call_meta, dot_meta, trigger, issue_meta) do
      meta = merge_meta(call_meta, dot_meta)

      format_issue(
        issue_meta,
        message: @message,
        trigger: trigger,
        line_no: meta[:line],
        column: meta[:column]
      )
    end

    defp merge_meta(call_meta, dot_meta) do
      [
        line: call_meta[:line] || dot_meta[:line],
        column: call_meta[:column] || dot_meta[:column]
      ]
    end
  end
end
