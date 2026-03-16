defmodule MusicLibrary.ScrobbleRules do
  @moduledoc """
  The ScrobbleRules context.
  """

  import Ecto.Query, warn: false

  require Logger

  alias LastFm.Track
  alias MusicLibrary.Repo
  alias MusicLibrary.ScrobbleRules.ScrobbleRule

  @type list_opts :: [
          type: atom(),
          enabled: boolean(),
          query: String.t(),
          offset: non_neg_integer(),
          limit: non_neg_integer()
        ]

  @spec list_scrobble_rules(list_opts()) :: [ScrobbleRule.t()]
  def list_scrobble_rules(opts \\ []) do
    query =
      from(r in ScrobbleRule, order_by: [desc: r.inserted_at])
      |> filter_scrobble_rules(opts)

    query =
      case Keyword.get(opts, :offset) do
        nil ->
          query

        offset ->
          from r in query,
            offset: ^offset
      end

    query =
      case Keyword.get(opts, :limit) do
        nil ->
          query

        limit ->
          from r in query,
            limit: ^limit
      end

    Repo.all(query)
  end

  @spec count_scrobble_rules(list_opts()) :: non_neg_integer()
  def count_scrobble_rules(opts \\ []) do
    from(r in ScrobbleRule)
    |> filter_scrobble_rules(opts)
    |> Repo.aggregate(:count)
  end

  @spec get_scrobble_rule!(integer()) :: ScrobbleRule.t()
  def get_scrobble_rule!(id), do: Repo.get!(ScrobbleRule, id)

  @spec create_scrobble_rule(map()) :: {:ok, ScrobbleRule.t()} | {:error, Ecto.Changeset.t()}
  def create_scrobble_rule(attrs \\ %{}) do
    %ScrobbleRule{}
    |> ScrobbleRule.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_scrobble_rule(ScrobbleRule.t(), map()) ::
          {:ok, ScrobbleRule.t()} | {:error, Ecto.Changeset.t()}
  def update_scrobble_rule(%ScrobbleRule{} = scrobble_rule, attrs) do
    scrobble_rule
    |> ScrobbleRule.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_scrobble_rule(ScrobbleRule.t()) ::
          {:ok, ScrobbleRule.t()} | {:error, Ecto.Changeset.t()}
  def delete_scrobble_rule(%ScrobbleRule{} = scrobble_rule) do
    Repo.delete(scrobble_rule)
  end

  @spec change_scrobble_rule(ScrobbleRule.t(), map()) :: Ecto.Changeset.t()
  def change_scrobble_rule(%ScrobbleRule{} = scrobble_rule, attrs \\ %{}) do
    ScrobbleRule.changeset(scrobble_rule, attrs)
  end

  @spec list_enabled_rules() :: [ScrobbleRule.t()]
  def list_enabled_rules do
    list_scrobble_rules(enabled: true)
  end

  @spec apply_album_rule(ScrobbleRule.t()) :: {:ok, non_neg_integer()} | {:error, term()}
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

  @spec apply_album_rule(ScrobbleRule.t(), [LastFm.Track.t()]) ::
          {:ok, non_neg_integer()} | {:error, term()}
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

  @spec apply_artist_rule(ScrobbleRule.t()) :: {:ok, non_neg_integer()} | {:error, term()}
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

  @spec apply_artist_rule(ScrobbleRule.t(), [LastFm.Track.t()]) ::
          {:ok, non_neg_integer()} | {:error, term()}
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

  @spec apply_rule(ScrobbleRule.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def apply_rule(%ScrobbleRule{type: :album} = rule) do
    apply_album_rule(rule)
  end

  def apply_rule(%ScrobbleRule{type: :artist} = rule) do
    apply_artist_rule(rule)
  end

  @spec apply_rule(ScrobbleRule.t(), [LastFm.Track.t()]) ::
          {:ok, non_neg_integer()} | {:error, term()}
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
  """
  @spec apply_all_album_rules([ScrobbleRule.t()]) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def apply_all_album_rules([]), do: {:ok, 0}

  def apply_all_album_rules(rules) when is_list(rules) do
    apply_all_rules_for_column(rules, "album", "$.title", nil)
  end

  @doc """
  Applies all album rules to a specific set of tracks in a single query.

  Uses a CASE statement to update the musicbrainz_id for all matching albums
  in one database operation, filtering by the provided tracks.
  """
  @spec apply_all_album_rules([ScrobbleRule.t()], [LastFm.Track.t()]) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def apply_all_album_rules([], _tracks), do: {:ok, 0}
  def apply_all_album_rules(_rules, []), do: {:ok, 0}

  def apply_all_album_rules(rules, tracks) when is_list(rules) and is_list(tracks) do
    apply_all_rules_for_column(rules, "album", "$.title", tracks)
  end

  @doc """
  Applies all artist rules in a single query.

  Uses a CASE statement to update the musicbrainz_id for all matching artists
  in one database operation, which is more efficient than applying rules individually.
  """
  @spec apply_all_artist_rules([ScrobbleRule.t()]) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def apply_all_artist_rules([]), do: {:ok, 0}

  def apply_all_artist_rules(rules) when is_list(rules) do
    apply_all_rules_for_column(rules, "artist", "$.name", nil)
  end

  @doc """
  Applies all artist rules to a specific set of tracks in a single query.

  Uses a CASE statement to update the musicbrainz_id for all matching artists
  in one database operation, filtering by the provided tracks.
  """
  @spec apply_all_artist_rules([ScrobbleRule.t()], [LastFm.Track.t()]) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def apply_all_artist_rules([], _tracks), do: {:ok, 0}
  def apply_all_artist_rules(_rules, []), do: {:ok, 0}

  def apply_all_artist_rules(rules, tracks) when is_list(rules) and is_list(tracks) do
    apply_all_rules_for_column(rules, "artist", "$.name", tracks)
  end

  @doc """
  Applies all enabled rules.

  This optimized version groups rules by type and applies all rules of each type
  in a single database query, which is much more efficient than applying each rule
  individually.
  """
  @spec apply_all_rules() :: [
          {:ok, {atom(), String.t(), non_neg_integer()}}
          | {:error, {atom(), String.t(), term()}}
        ]
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
  """
  @spec apply_all_rules([LastFm.Track.t()]) :: [
          {:ok, {atom(), String.t(), non_neg_integer()}}
          | {:error, {atom(), String.t(), term()}}
        ]
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

  @spec count_album_matches(ScrobbleRule.t()) :: non_neg_integer()
  def count_album_matches(%ScrobbleRule{type: :album} = rule) do
    query =
      from(t in Track,
        where: fragment("json_extract(?, '$.title') = ?", t.album, ^rule.match_value),
        select: count(t.scrobbled_at_uts)
      )

    Repo.one(query) || 0
  end

  @spec count_artist_matches(ScrobbleRule.t()) :: non_neg_integer()
  def count_artist_matches(%ScrobbleRule{type: :artist} = rule) do
    query =
      from(t in Track,
        where: fragment("json_extract(?, '$.name') = ?", t.artist, ^rule.match_value),
        select: count(t.scrobbled_at_uts)
      )

    Repo.one(query) || 0
  end

  @spec count_rule_matches(ScrobbleRule.t()) :: non_neg_integer()
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
  """
  @spec log_apply_results([
          {:ok, {atom(), String.t(), non_neg_integer()}}
          | {:error, {atom(), String.t(), term()}}
        ]) :: :ok
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

    if total_tracks_updated > 0 do
      Logger.info(fn ->
        "Scrobble rules application completed: " <>
          "applied #{total_applied} rules, " <>
          "#{total_errors} errors, " <>
          "#{total_tracks_updated} tracks updated"
      end)
    end

    Enum.each(errors, fn {:error, {type, match_value, reason}} ->
      Logger.error(fn ->
        "failed to apply #{type} rule " <>
          "with match #{match_value} " <>
          "with reason #{inspect(reason)}"
      end)
    end)
  end

  defp filter_scrobble_rules(query, opts) do
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

    case Keyword.get(opts, :query) do
      q when q in [nil, ""] ->
        query

      q ->
        like = "%#{q}%"

        from r in query,
          where:
            like(r.match_value, ^like) or
              like(r.target_musicbrainz_id, ^like) or
              like(r.description, ^like)
    end
  end

  # column and json_path are hardcoded string literals from internal callers,
  # never user input. All user-derived values use parameterized ? placeholders.
  # sobelow_skip ["SQL.Query"]
  defp apply_all_rules_for_column(rules, column, json_path, tracks) do
    {case_clauses, case_params} =
      Enum.reduce(rules, {"", []}, fn rule, {sql_acc, params_acc} ->
        clause =
          "WHEN json_extract(#{column}, '#{json_path}') = ? THEN json_set(#{column}, '$.musicbrainz_id', ?) "

        {sql_acc <> clause, params_acc ++ [rule.match_value, rule.target_musicbrainz_id]}
      end)

    case_sql = "CASE #{case_clauses}ELSE #{column} END"

    match_values = Enum.map(rules, & &1.match_value)
    match_placeholders = Enum.map_join(match_values, ", ", fn _ -> "?" end)

    {where_sql, where_params} =
      case tracks do
        nil ->
          {"json_extract(#{column}, '#{json_path}') IN (#{match_placeholders})", match_values}

        tracks ->
          track_scrobbled_at_uts = Enum.map(tracks, & &1.scrobbled_at_uts)
          track_placeholders = Enum.map_join(track_scrobbled_at_uts, ", ", fn _ -> "?" end)

          where =
            "json_extract(#{column}, '#{json_path}') IN (#{match_placeholders}) AND " <>
              "scrobbled_at_uts IN (#{track_placeholders})"

          {where, match_values ++ track_scrobbled_at_uts}
      end

    sql = """
    UPDATE scrobbled_tracks
    SET #{column} = #{case_sql}
    WHERE #{where_sql}
    """

    all_params = case_params ++ where_params

    case Repo.query(sql, all_params) do
      {:ok, %{num_rows: count}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end
end
