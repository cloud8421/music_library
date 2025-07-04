defmodule MusicLibrary.ScrobbleRules do
  @moduledoc """
  The ScrobbleRules context.
  """

  import Ecto.Query, warn: false

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
  Applies all enabled rules.

  ## Examples

      iex> apply_all_rules()
      {:ok, [{:album, 5}, {:artist, 10}]}

  """
  def apply_all_rules do
    rules = list_enabled_rules()

    Enum.map(rules, fn rule ->
      case apply_rule(rule) do
        {:ok, count} -> {:ok, {rule.type, rule.match_value, count}}
        {:error, reason} -> {:error, {rule.type, rule.match_value, reason}}
      end
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
end
