defmodule MusicLibrary.SqlHelpers do
  @moduledoc """
  SQL helper macros for common database operations.

  This module provides macros for building SQL fragments used throughout
  the application, particularly for SQLite JSON operations and CASE statements.

  ## Reference

  Pattern inspired by: https://manusachi.com/blog/sql-case-ecto#index
  """

  @doc """
  Creates a SQL fragment for extracting a value from a JSON field.

  ## Examples

      # Extract the title from an album JSON field
      json_extract(t.album, "$.title")
      #=> fragment("json_extract(?, ?)", t.album, "$.title")

      # Use in a where clause
      where: json_extract(t.album, "$.title") == ^album_title

  """
  defmacro json_extract(field, path) do
    quote do
      fragment("json_extract(?, ?)", unquote(field), unquote(path))
    end
  end

  @doc """
  Creates a SQL fragment for setting a value in a JSON field.

  ## Examples

      # Set the musicbrainz_id in an album JSON field
      json_set(t.album, "$.musicbrainz_id", ^mbid)
      #=> fragment("json_set(?, ?, ?)", t.album, "$.musicbrainz_id", ^mbid)

      # Use in an update statement
      update: [set: [album: json_set(t.album, "$.musicbrainz_id", ^mbid)]]

  """
  defmacro json_set(field, path, value) do
    quote do
      fragment("json_set(?, ?, ?)", unquote(field), unquote(path), unquote(value))
    end
  end

  @doc """
  Builds a SQL CASE...WHEN...ELSE statement for batch updates.

  Takes a list of rules and a field specification, and builds the SQL
  for a CASE statement that can update multiple values in a single query.

  ## Parameters

    * `rules` - List of rules with `match_value` and `target_musicbrainz_id`
    * `field_spec` - Map with `:field` (table field), `:json_path` (JSON path to match),
      and `:update_path` (JSON path to update)

  ## Returns

  A tuple of `{case_sql, case_params, match_values}` where:
    * `case_sql` - The CASE...WHEN...ELSE SQL string
    * `case_params` - Parameters for the CASE statement
    * `match_values` - List of match values from rules

  ## Examples

      field_spec = %{
        field: "album",
        json_path: "$.title",
        update_path: "$.musicbrainz_id"
      }
      
      case_when(rules, field_spec)
      #=> {"CASE WHEN json_extract(album, '$.title') = ? THEN json_set(album, '$.musicbrainz_id', ?) ELSE album END",
      #    ["Album 1", "mbid-1", "Album 2", "mbid-2"],
      #    ["Album 1", "Album 2"]}

  """
  def case_when(rules, field_spec) when is_list(rules) and is_map(field_spec) do
    %{field: field, json_path: json_path, update_path: update_path} = field_spec

    {case_clauses, case_params} =
      rules
      |> Enum.reduce({"", []}, fn rule, {sql_acc, params_acc} ->
        clause =
          "WHEN json_extract(#{field}, '#{json_path}') = ? THEN json_set(#{field}, '#{update_path}', ?) "

        {sql_acc <> clause, params_acc ++ [rule.match_value, rule.target_musicbrainz_id]}
      end)

    case_sql = "CASE #{case_clauses}ELSE #{field} END"
    match_values = Enum.map(rules, & &1.match_value)

    {case_sql, case_params, match_values}
  end
end
