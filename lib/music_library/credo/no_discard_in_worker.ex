if Code.ensure_loaded?(Credo) do
  defmodule MusicLibrary.Credo.NoDiscardInWorker do
    @moduledoc false

    use Credo.Check,
      base_priority: :high,
      category: :warning,
      explanations: [
        check: """
        Oban workers should never return `{:discard, reason}` — this return value
        is deprecated since Oban 2.14. Use `{:cancel, reason}` instead.

        The two forms have identical semantics: the job is permanently cancelled
        and will never be retried.
        """
      ]

    @message "Use `{:cancel, reason}` instead of `{:discard, reason}` in Oban workers."

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
        if oban_worker_body?(body) do
          issues ++ collect_discard_issues(body, issue_meta)
        else
          issues
        end

      {ast, issues}
    end

    defp traverse_module(ast, issues, _issue_meta), do: {ast, issues}

    # Check if the module body includes `use Oban.Worker`
    defp oban_worker_body?(body) do
      Credo.Code.prewalk(body, &traverse_oban_use/2, false)
    end

    defp traverse_oban_use({:defmodule, _meta, _args}, found?), do: {nil, found?}

    defp traverse_oban_use(
           {:use, _meta, [{:__aliases__, _alias_meta, [:Oban, :Worker]} | _rest]} = ast,
           _found?
         ) do
      {ast, true}
    end

    defp traverse_oban_use(ast, found?), do: {ast, found?}

    # Collect all {:discard, reason} tuples within the module body
    defp collect_discard_issues(body, issue_meta) do
      Credo.Code.prewalk(body, &traverse_discard_tuple(&1, &2, issue_meta))
    end

    defp traverse_discard_tuple({:defmodule, _meta, _args}, issues, _issue_meta),
      do: {nil, issues}

    defp traverse_discard_tuple({:discard, meta, [_reason]} = ast, issues, issue_meta) do
      {ast, issues ++ [issue_for(meta, issue_meta)]}
    end

    defp traverse_discard_tuple(ast, issues, _issue_meta), do: {ast, issues}

    defp issue_for(meta, issue_meta) do
      format_issue(
        issue_meta,
        message: @message,
        trigger: "{:discard, reason}",
        line_no: meta[:line],
        column: meta[:column]
      )
    end
  end
end
