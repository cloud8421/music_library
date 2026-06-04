if Code.ensure_loaded?(Credo) do
  defmodule MusicLibrary.Credo.NoWriteToFtsTable do
    @moduledoc false

    use Credo.Check,
      base_priority: :high,
      category: :warning,
      explanations: [
        check: """
        Never write directly to FTS5 virtual tables. The `records_search_index`
        table is an FTS5 virtual table auto-synced via database triggers on the
        `records` table.

        Direct writes (INSERT, UPDATE, DELETE, or `INSERT ALL`) to
        `records_search_index` bypass the triggers and corrupt the search index.
        Always write to the `records` table instead.
        """
      ]

    @message "Do not write directly to `records_search_index` — it is auto-synced via triggers."

    @mutation_functions [
      :insert,
      :insert!,
      :insert_all,
      :update,
      :update!,
      :update_all,
      :delete,
      :delete!
    ]

    def run(source_file, params \\ []) do
      issue_meta = IssueMeta.for(source_file, params)

      Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    end

    # ── Repo.function("records_search_index", ...) ──────────────────────────

    defp traverse(
           {{:., dot_meta, [{:__aliases__, _, [:Repo]}, function]}, call_meta, [first_arg | _]} =
             ast,
           issues,
           issue_meta
         ) do
      issues =
        if function in @mutation_functions and fts_table_string?(first_arg) do
          issues ++ [issue_for(call_meta, dot_meta, "Repo.#{function}", issue_meta)]
        else
          issues
        end

      {ast, issues}
    end

    # ── MusicLibrary.Repo.function("records_search_index", ...) ──────────────

    defp traverse(
           {{:., dot_meta, [{:__aliases__, _, [:MusicLibrary, :Repo]}, function]}, call_meta,
            [first_arg | _]} = ast,
           issues,
           issue_meta
         ) do
      issues =
        if function in @mutation_functions and fts_table_string?(first_arg) do
          issues ++
            [issue_for(call_meta, dot_meta, "MusicLibrary.Repo.#{function}", issue_meta)]
        else
          issues
        end

      {ast, issues}
    end

    # ── Any-module.insert_all("records_search_index", ...) ──────────────────

    defp traverse(
           {{:., _, [{:__aliases__, _, _mod_parts}, :insert_all]}, call_meta, [first_arg | _]} =
             ast,
           issues,
           issue_meta
         ) do
      issues =
        if fts_table_string?(first_arg) do
          issues ++ [issue_for(call_meta, call_meta, "insert_all", issue_meta)]
        else
          issues
        end

      {ast, issues}
    end

    # ── Repo.function(%Records.SearchIndex{}) ───────────────────────────────

    defp traverse(
           {{:., dot_meta, [{:__aliases__, _, [:Repo]}, function]}, call_meta,
            [
              {:%, _pct_meta, [{:__aliases__, _as_meta, [:Records, :SearchIndex]}, _map]}
              | _rest
            ]} = ast,
           issues,
           issue_meta
         ) do
      issues =
        if function in @mutation_functions do
          issues ++
            [
              issue_for(
                call_meta,
                dot_meta,
                "Repo.#{function}(%Records.SearchIndex{})",
                issue_meta
              )
            ]
        else
          issues
        end

      {ast, issues}
    end

    defp traverse(ast, issues, _issue_meta), do: {ast, issues}

    # ── Helpers ──────────────────────────────────────────────────────────────

    defp fts_table_string?("records_search_index"), do: true
    defp fts_table_string?({:in, _, ["records_search_index"]}), do: true
    defp fts_table_string?(_), do: false

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
