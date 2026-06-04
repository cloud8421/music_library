if Code.ensure_loaded?(Credo) do
  defmodule MusicLibrary.Credo.ErrorResponseImplementsBehaviour do
    @moduledoc false

    use Credo.Check,
      id: "EX2002",
      base_priority: :high,
      category: :warning,
      explanations: [
        check: """
        Every per-API ErrorResponse module must implement the
        `MusicLibrary.ErrorResponse` behaviour.

        The `MusicLibrary.Worker.ErrorHandler.to_oban_result/1` function
        dispatches on `mod.retryable?/1` and `mod.retry_delay_seconds/1`
        for any struct matching the `@error_structs` list. If a new API's
        ErrorResponse module forgets to implement the behaviour, workers
        will crash at runtime instead of snoozing or cancelling correctly.
        """
      ]

    alias Credo.Code.Name

    @message "ErrorResponse modules must implement `@behaviour MusicLibrary.ErrorResponse`."

    def run(source_file, params \\ []) do
      issue_meta = IssueMeta.for(source_file, params)

      Credo.Code.prewalk(source_file, &traverse_module(&1, &2, issue_meta))
    end

    defp traverse_module(
           {:defmodule, _meta, [module_name, [do: body]]} = ast,
           issues,
           issue_meta
         ) do
      issues =
        if error_response_module?(module_name) do
          if implements_behaviour?(body) do
            issues
          else
            issues ++ [issue_for(module_name, issue_meta)]
          end
        else
          issues
        end

      {ast, issues}
    end

    defp traverse_module(ast, issues, _issue_meta), do: {ast, issues}

    # Check if module name ends with `.API.ErrorResponse`
    defp error_response_module?({:__aliases__, _meta, module_parts}) do
      module_parts
      |> Enum.reverse()
      |> Enum.take(2)
      |> then(&(&1 == [:ErrorResponse, :API] || &1 == [ErrorResponse, API]))
    end

    defp error_response_module?(_), do: false

    # Check if the module body contains @behaviour MusicLibrary.ErrorResponse
    defp implements_behaviour?(body) do
      Credo.Code.prewalk(body, &traverse_behaviour/2, false)
    end

    defp traverse_behaviour({:defmodule, _meta, _args}, found?), do: {nil, found?}

    defp traverse_behaviour(
           {:@, _meta,
            [
              {:behaviour, _b_meta,
               [
                 {:__aliases__, _alias_meta, [:MusicLibrary, :ErrorResponse]}
               ]}
            ]} = ast,
           _found?
         ) do
      {ast, true}
    end

    defp traverse_behaviour(ast, found?), do: {ast, found?}

    defp issue_for(module_name, issue_meta) do
      # Extract line from the module_name AST node metadata
      {:__aliases__, meta, _} = module_name

      format_issue(
        issue_meta,
        message: @message,
        trigger: Name.full(module_name),
        line_no: meta[:line]
      )
    end
  end
end
