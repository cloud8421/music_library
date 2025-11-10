defmodule MusicLibrary.ScrobbleRules do
  @moduledoc """
  The ScrobbleRules context.
  """

  import Ecto.Query, warn: false

  require Logger

  alias LastFm.Track
  alias MusicLibrary.Repo
  alias MusicLibrary.ScrobbleRules.ScrobbleRule

  @doc """
  Returns the list of scrobble_rules.

  ## Examples

      iex> list_scrobble_rules()
      [%ScrobbleRule{}, ...]

  """
  def list_scrobble_rules(opts \\ []) do
    query =
      from r in ScrobbleRule,
        order_by: [desc: r.inserted_at]

    query =
      case Keyword.get(opts, :type) do
        nil ->
          query

        type ->
          from r in query,
            where: r.type == ^type
      end

    query =
      case Keyword.get(opts, :enabled) do
        nil ->
          query

        enabled ->
          from r in query,
            where: r.enabled == ^enabled
      end

    Repo.all(query)
  end

  @doc """
  Gets a single scrobble_rule.

  Raises `Ecto.NoResultsError` if the Scrobble rule does not exist.

  ## Examples

      iex> get_scrobble_rule!(123)
      %ScrobbleRule{}

      iex> get_scrobble_rule!(456)
      ** (Ecto.NoResultsError)

  """
  def get_scrobble_rule!(id), do: Repo.get!(ScrobbleRule, id)

  @doc """
  Creates a scrobble_rule.

  ## Examples

      iex> create_scrobble_rule(%{field: value})
      {:ok, %ScrobbleRule{}}

      iex> create_scrobble_rule(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_scrobble_rule(attrs \\ %{}) do
    %ScrobbleRule{}
    |> ScrobbleRule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a scrobble_rule.

  ## Examples

      iex> update_scrobble_rule(scrobble_rule, %{field: new_value})
      {:ok, %ScrobbleRule{}}

      iex> update_scrobble_rule(scrobble_rule, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_scrobble_rule(%ScrobbleRule{} = scrobble_rule, attrs) do
    scrobble_rule
    |> ScrobbleRule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a scrobble_rule.

  ## Examples

      iex> delete_scrobble_rule(scrobble_rule)
      {:ok, %ScrobbleRule{}}

      iex> delete_scrobble_rule(scrobble_rule)
      {:error, %Ecto.Changeset{}}

  """
  def delete_scrobble_rule(%ScrobbleRule{} = scrobble_rule) do
    Repo.delete(scrobble_rule)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking scrobble_rule changes.

  ## Examples

      iex> change_scrobble_rule(scrobble_rule)
      %Ecto.Changeset{data: %ScrobbleRule{}}

  """
  def change_scrobble_rule(%ScrobbleRule{} = scrobble_rule, attrs \\ %{}) do
    ScrobbleRule.changeset(scrobble_rule, attrs)
  end

  @doc """
  Returns the list of enabled scrobble_rules.

  ## Examples

      iex> list_enabled_rules()
      [%ScrobbleRule{}, ...]

  """
  def list_enabled_rules do
    list_scrobble_rules(enabled: true)
  end

  @doc """
  Applies an album rule to all matching scrobbled tracks.

  ## Examples

      iex> apply_album_rule(rule)
      {:ok, 5}

      iex> apply_album_rule(rule)
      {:error, :invalid_rule_type}

  """
  def apply_album_rule(%ScrobbleRule{type: :album} = rule) do
    update_query =
      from(t in Track,
        where: fragment("json_extract(?, '$.title') = ?", t.album, ^rule.match_value),
        update: [
          set: [
            album:
              fragment(
                "json_set(?, '$.musicbrainz_id', ?)",
                t.album,
                ^rule.target_musicbrainz_id
              )
          ]
        ]
      )

    case Repo.update_all(update_query, []) do
      {count, _} -> {:ok, count}
      error -> {:error, error}
    end
  end

  @doc """
  Applies an album rule to a specific set of scrobbled tracks.

  ## Examples

      iex> apply_album_rule(rule, tracks)
      {:ok, 3}

      iex> apply_album_rule(rule, tracks)
      {:error, :invalid_rule_type}

  """
  def apply_album_rule(%ScrobbleRule{type: :album} = rule, tracks) do
    track_scrobbled_at_uts = Enum.map(tracks, & &1.scrobbled_at_uts)

    update_query =
      from(t in Track,
        where:
          fragment("json_extract(?, '$.title') = ?", t.album, ^rule.match_value) and
            t.scrobbled_at_uts in ^track_scrobbled_at_uts,
        update: [
          set: [
            album:
              fragment(
                "json_set(?, '$.musicbrainz_id', ?)",
                t.album,
                ^rule.target_musicbrainz_id
              )
          ]
        ]
      )

    case Repo.update_all(update_query, []) do
      {count, _} -> {:ok, count}
      error -> {:error, error}
    end
  end

  @doc """
  Applies an artist rule to all matching scrobbled tracks.

  ## Examples

      iex> apply_artist_rule(rule)
      {:ok, 10}

      iex> apply_artist_rule(rule)
      {:error, :invalid_rule_type}

  """
  def apply_artist_rule(%ScrobbleRule{type: :artist} = rule) do
    update_query =
      from(t in Track,
        where: fragment("json_extract(?, '$.name') = ?", t.artist, ^rule.match_value),
        update: [
          set: [
            artist:
              fragment(
                "json_set(?, '$.musicbrainz_id', ?)",
                t.artist,
                ^rule.target_musicbrainz_id
              )
          ]
        ]
      )

    case Repo.update_all(update_query, []) do
      {count, _} -> {:ok, count}
      error -> {:error, error}
    end
  end

  @doc """
  Applies an artist rule to a specific set of scrobbled tracks.

  ## Examples

      iex> apply_artist_rule(rule, tracks)
      {:ok, 7}

      iex> apply_artist_rule(rule, tracks)
      {:error, :invalid_rule_type}

  """
  def apply_artist_rule(%ScrobbleRule{type: :artist} = rule, tracks) do
    track_scrobbled_at_uts = Enum.map(tracks, & &1.scrobbled_at_uts)

    update_query =
      from(t in Track,
        where:
          fragment("json_extract(?, '$.name') = ?", t.artist, ^rule.match_value) and
            t.scrobbled_at_uts in ^track_scrobbled_at_uts,
        update: [
          set: [
            artist:
              fragment(
                "json_set(?, '$.musicbrainz_id', ?)",
                t.artist,
                ^rule.target_musicbrainz_id
              )
          ]
        ]
      )

    case Repo.update_all(update_query, []) do
      {count, _} -> {:ok, count}
      error -> {:error, error}
    end
  end

  @doc """
  Applies a single rule based on its type.

  ## Examples

      iex> apply_rule(rule)
      {:ok, 5}

      iex> apply_rule(rule)
      {:error, "Invalid rule type"}

  """
  def apply_rule(%ScrobbleRule{type: :album} = rule) do
    apply_album_rule(rule)
  end

  def apply_rule(%ScrobbleRule{type: :artist} = rule) do
    apply_artist_rule(rule)
  end

  @doc """
  Applies a single rule to a specific set of tracks based on its type.

  ## Examples

      iex> apply_rule(rule, tracks)
      {:ok, 3}

      iex> apply_rule(rule, tracks)
      {:error, "Invalid rule type"}

  """
  def apply_rule(%ScrobbleRule{type: :album} = rule, tracks) do
    apply_album_rule(rule, tracks)
  end

  def apply_rule(%ScrobbleRule{type: :artist} = rule, tracks) do
    apply_artist_rule(rule, tracks)
  end

  @doc """
  Applies all album rules in a single query.

  Uses a CASE statement to update the musicbrainz_id for all matching albums
  in one database operation, which is more efficient than applying rules individually.

  ## Examples

      iex> apply_all_album_rules([rule1, rule2])
      {:ok, 15}

  """
  def apply_all_album_rules([]), do: {:ok, 0}

  def apply_all_album_rules(rules) when is_list(rules) do
    # Build CASE WHEN clauses dynamically
    {case_clauses, case_params} =
      rules
      |> Enum.reduce({"", []}, fn rule, {sql_acc, params_acc} ->
        clause = "WHEN json_extract(album, '$.title') = ? THEN json_set(album, '$.musicbrainz_id', ?) "
        {sql_acc <> clause, params_acc ++ [rule.match_value, rule.target_musicbrainz_id]}
      end)

    # Build complete UPDATE statement
    case_sql = "CASE #{case_clauses}ELSE album END"

    # Build WHERE IN clause
    match_values = Enum.map(rules, & &1.match_value)
    in_placeholders = Enum.map(match_values, fn _ -> "?" end) |> Enum.join(", ")
    where_sql = "json_extract(album, '$.title') IN (#{in_placeholders})"

    # Complete SQL
    sql = """
    UPDATE scrobbled_tracks 
    SET album = #{case_sql}
    WHERE #{where_sql}
    """

    # All parameters: case params + where params
    all_params = case_params ++ match_values

    # Execute the query
    case Ecto.Adapters.SQL.query(Repo, sql, all_params) do
      {:ok, %{num_rows: count}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Applies all album rules to a specific set of tracks in a single query.

  Uses a CASE statement to update the musicbrainz_id for all matching albums
  in one database operation, filtering by the provided tracks.

  ## Examples

      iex> apply_all_album_rules([rule1, rule2], tracks)
      {:ok, 3}

  """
  def apply_all_album_rules([], _tracks), do: {:ok, 0}
  def apply_all_album_rules(_rules, []), do: {:ok, 0}

  def apply_all_album_rules(rules, tracks) when is_list(rules) and is_list(tracks) do
    # Build CASE WHEN clauses dynamically
    {case_clauses, case_params} =
      rules
      |> Enum.reduce({"", []}, fn rule, {sql_acc, params_acc} ->
        clause = "WHEN json_extract(album, '$.title') = ? THEN json_set(album, '$.musicbrainz_id', ?) "
        {sql_acc <> clause, params_acc ++ [rule.match_value, rule.target_musicbrainz_id]}
      end)

    # Build complete UPDATE statement
    case_sql = "CASE #{case_clauses}ELSE album END"

    # Build WHERE IN clause for album titles
    match_values = Enum.map(rules, & &1.match_value)
    album_placeholders = Enum.map(match_values, fn _ -> "?" end) |> Enum.join(", ")
    
    # Build WHERE IN clause for track timestamps
    track_scrobbled_at_uts = Enum.map(tracks, & &1.scrobbled_at_uts)
    track_placeholders = Enum.map(track_scrobbled_at_uts, fn _ -> "?" end) |> Enum.join(", ")
    
    where_sql = 
      "json_extract(album, '$.title') IN (#{album_placeholders}) AND " <>
      "scrobbled_at_uts IN (#{track_placeholders})"

    # Complete SQL
    sql = """
    UPDATE scrobbled_tracks 
    SET album = #{case_sql}
    WHERE #{where_sql}
    """

    # All parameters: case params + album match values + track timestamps
    all_params = case_params ++ match_values ++ track_scrobbled_at_uts

    # Execute the query
    case Ecto.Adapters.SQL.query(Repo, sql, all_params) do
      {:ok, %{num_rows: count}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Applies all artist rules in a single query.

  Uses a CASE statement to update the musicbrainz_id for all matching artists
  in one database operation, which is more efficient than applying rules individually.

  ## Examples

      iex> apply_all_artist_rules([rule1, rule2])
      {:ok, 25}

  """
  def apply_all_artist_rules([]), do: {:ok, 0}

  def apply_all_artist_rules(rules) when is_list(rules) do
    # Build CASE WHEN clauses dynamically
    {case_clauses, case_params} =
      rules
      |> Enum.reduce({"", []}, fn rule, {sql_acc, params_acc} ->
        clause = "WHEN json_extract(artist, '$.name') = ? THEN json_set(artist, '$.musicbrainz_id', ?) "
        {sql_acc <> clause, params_acc ++ [rule.match_value, rule.target_musicbrainz_id]}
      end)

    # Build complete UPDATE statement
    case_sql = "CASE #{case_clauses}ELSE artist END"

    # Build WHERE IN clause
    match_values = Enum.map(rules, & &1.match_value)
    in_placeholders = Enum.map(match_values, fn _ -> "?" end) |> Enum.join(", ")
    where_sql = "json_extract(artist, '$.name') IN (#{in_placeholders})"

    # Complete SQL
    sql = """
    UPDATE scrobbled_tracks 
    SET artist = #{case_sql}
    WHERE #{where_sql}
    """

    # All parameters: case params + where params
    all_params = case_params ++ match_values

    # Execute the query
    case Ecto.Adapters.SQL.query(Repo, sql, all_params) do
      {:ok, %{num_rows: count}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Applies all artist rules to a specific set of tracks in a single query.

  Uses a CASE statement to update the musicbrainz_id for all matching artists
  in one database operation, filtering by the provided tracks.

  ## Examples

      iex> apply_all_artist_rules([rule1, rule2], tracks)
      {:ok, 7}

  """
  def apply_all_artist_rules([], _tracks), do: {:ok, 0}
  def apply_all_artist_rules(_rules, []), do: {:ok, 0}

  def apply_all_artist_rules(rules, tracks) when is_list(rules) and is_list(tracks) do
    # Build CASE WHEN clauses dynamically
    {case_clauses, case_params} =
      rules
      |> Enum.reduce({"", []}, fn rule, {sql_acc, params_acc} ->
        clause = "WHEN json_extract(artist, '$.name') = ? THEN json_set(artist, '$.musicbrainz_id', ?) "
        {sql_acc <> clause, params_acc ++ [rule.match_value, rule.target_musicbrainz_id]}
      end)

    # Build complete UPDATE statement
    case_sql = "CASE #{case_clauses}ELSE artist END"

    # Build WHERE IN clause for artist names
    match_values = Enum.map(rules, & &1.match_value)
    artist_placeholders = Enum.map(match_values, fn _ -> "?" end) |> Enum.join(", ")
    
    # Build WHERE IN clause for track timestamps
    track_scrobbled_at_uts = Enum.map(tracks, & &1.scrobbled_at_uts)
    track_placeholders = Enum.map(track_scrobbled_at_uts, fn _ -> "?" end) |> Enum.join(", ")
    
    where_sql = 
      "json_extract(artist, '$.name') IN (#{artist_placeholders}) AND " <>
      "scrobbled_at_uts IN (#{track_placeholders})"

    # Complete SQL
    sql = """
    UPDATE scrobbled_tracks 
    SET artist = #{case_sql}
    WHERE #{where_sql}
    """

    # All parameters: case params + artist match values + track timestamps
    all_params = case_params ++ match_values ++ track_scrobbled_at_uts

    # Execute the query
    case Ecto.Adapters.SQL.query(Repo, sql, all_params) do
      {:ok, %{num_rows: count}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Applies all enabled rules.

  This optimized version groups rules by type and applies all rules of each type
  in a single database query, which is much more efficient than applying each rule
  individually.

  ## Examples

      iex> apply_all_rules()
      {:ok, [{:album, 5}, {:artist, 10}]}

  """
  def apply_all_rules do
    :telemetry.span([:music_library, :scrobble_rules, :apply_all_rules], %{}, fn ->
      enabled_rules = list_enabled_rules()

      # Group rules by type
      {album_rules, artist_rules} =
        Enum.split_with(enabled_rules, fn rule -> rule.type == :album end)

      # Apply all album rules in one query
      album_result =
        case apply_all_album_rules(album_rules) do
          {:ok, count} ->
            # Return the count for each album rule (total updated)
            # Note: this returns the same count for each rule since they're applied together
            Enum.map(album_rules, fn rule ->
              {:ok, {rule.type, rule.match_value, count}}
            end)

          {:error, reason} ->
            Enum.map(album_rules, fn rule ->
              {:error, {rule.type, rule.match_value, reason}}
            end)
        end

      # Apply all artist rules in one query
      artist_result =
        case apply_all_artist_rules(artist_rules) do
          {:ok, count} ->
            # Return the count for each artist rule (total updated)
            # Note: this returns the same count for each rule since they're applied together
            Enum.map(artist_rules, fn rule ->
              {:ok, {rule.type, rule.match_value, count}}
            end)

          {:error, reason} ->
            Enum.map(artist_rules, fn rule ->
              {:error, {rule.type, rule.match_value, reason}}
            end)
        end

      result = album_result ++ artist_result

      {result, %{scrobble_track_count: :all}}
    end)
  end

  @doc """
  Applies all enabled rules to a specific set of tracks.

  This optimized version groups rules by type and applies all rules of each type
  in a single database query, filtering by the provided tracks.

  ## Examples

      iex> apply_all_rules(tracks)
      [{:ok, {:album, "Some Album", 5}}, {:error, {:artist, "Some Artist", "reason"}}]

  """
  def apply_all_rules([]) do
    list_enabled_rules()
    |> Enum.map(fn rule ->
      {:ok, {rule.type, rule.match_value, 0}}
    end)
  end

  def apply_all_rules(tracks) do
    :telemetry.span([:music_library, :scrobble_rules, :apply_all_rules], %{}, fn ->
      enabled_rules = list_enabled_rules()

      # Group rules by type
      {album_rules, artist_rules} =
        Enum.split_with(enabled_rules, fn rule -> rule.type == :album end)

      # Apply all album rules in one query
      album_result =
        case apply_all_album_rules(album_rules, tracks) do
          {:ok, count} ->
            Enum.map(album_rules, fn rule ->
              {:ok, {rule.type, rule.match_value, count}}
            end)

          {:error, reason} ->
            Enum.map(album_rules, fn rule ->
              {:error, {rule.type, rule.match_value, reason}}
            end)
        end

      # Apply all artist rules in one query
      artist_result =
        case apply_all_artist_rules(artist_rules, tracks) do
          {:ok, count} ->
            Enum.map(artist_rules, fn rule ->
              {:ok, {rule.type, rule.match_value, count}}
            end)

          {:error, reason} ->
            Enum.map(artist_rules, fn rule ->
              {:error, {rule.type, rule.match_value, reason}}
            end)
        end

      result = album_result ++ artist_result

      {result, %{scrobble_track_count: Enum.count(tracks)}}
    end)
  end

  @doc """
  Counts how many tracks would be affected by an album rule.

  ## Examples

      iex> count_album_matches(rule)
      5

  """
  def count_album_matches(%ScrobbleRule{type: :album} = rule) do
    query =
      from(t in Track,
        where: fragment("json_extract(?, '$.title') = ?", t.album, ^rule.match_value),
        select: count(t.scrobbled_at_uts)
      )

    Repo.one(query) || 0
  end

  @doc """
  Counts how many tracks would be affected by an artist rule.

  ## Examples

      iex> count_artist_matches(rule)
      10

  """
  def count_artist_matches(%ScrobbleRule{type: :artist} = rule) do
    query =
      from(t in Track,
        where: fragment("json_extract(?, '$.name') = ?", t.artist, ^rule.match_value),
        select: count(t.scrobbled_at_uts)
      )

    Repo.one(query) || 0
  end

  @doc """
  Counts how many tracks would be affected by a rule.

  ## Examples

      iex> count_rule_matches(rule)
      5

  """
  def count_rule_matches(%ScrobbleRule{type: :album} = rule) do
    count_album_matches(rule)
  end

  def count_rule_matches(%ScrobbleRule{type: :artist} = rule) do
    count_artist_matches(rule)
  end

  @doc """
  Logs the results of applying scrobble rules.

  Takes a list of results from rule application and logs summary statistics
  and any errors that occurred.

  ## Examples

      iex> log_apply_results([{:ok, {:album, "Album", 5}}, {:error, {:artist, "Artist", "reason"}}])
      :ok

  """
  def log_apply_results(results) do
    {applied, errors} =
      Enum.split_with(results, fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

    total_applied = length(applied)
    total_errors = length(errors)

    total_tracks_updated =
      applied
      |> Enum.map(fn {:ok, {_, _, count}} -> count end)
      |> Enum.sum()

    Logger.info(fn ->
      "Scrobble rules application completed: " <>
        "applied #{total_applied} rules, " <>
        "#{total_errors} errors, " <>
        "#{total_tracks_updated} tracks updated"
    end)

    Enum.each(errors, fn {:error, {type, match_value, reason}} ->
      Logger.error(fn ->
        "failed to apply #{type} rule " <>
          "with match #{match_value} " <>
          "with reason #{inspect(reason)}"
      end)
    end)
  end
end
