defmodule MusicLibrary.Records.Similarity do
  @moduledoc """
  Functions for calculating and finding similar records based on embeddings.
  """

  import Ecto.Query
  import SqliteVec.Ecto.Query

  alias MusicLibrary.Artists
  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibrary.Records
  alias MusicLibrary.Records.{Record, RecordEmbedding}
  alias MusicLibrary.Repo
  alias MusicLibrary.Worker.GenerateRecordEmbedding

  @max_distance Application.compile_env!(:music_library, :similarity)[:max_distance]

  @doc """
  Generates a text representation of a record for embedding generation.

  The representation includes:
  - Title
  - Artist names
  - Genres
  - Release year
  - Type (album, EP, etc.)
  - Artist musical style summaries (from Wikipedia, falling back to Discogs)
  """
  def text_representation(%Record{} = record) do
    artist_infos =
      record.artists
      |> Enum.map(& &1.musicbrainz_id)
      |> Artists.get_artist_infos()

    artist_names = Record.artist_names(record)
    genres = Enum.join(record.genres, ", ")
    year = extract_year(record.release_date)
    type = humanize_type(record.type)

    """
    Album: #{record.title}
    Artists: #{artist_names}
    Genres: #{genres}
    Released: #{year}
    Type: #{type}

    #{artist_infos_summary(artist_infos)}
    """
    |> String.trim()
  end

  defp artist_infos_summary([]), do: ""

  defp artist_infos_summary(artist_infos) do
    artist_infos
    |> Enum.map(&artist_info_summary/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp artist_info_summary(artist_info) do
    cond do
      wikipedia_available?(artist_info) ->
        wikipedia_artist_summary(artist_info)

      discogs_available?(artist_info) ->
        discogs_artist_summary(artist_info)

      true ->
        ""
    end
  end

  defp wikipedia_available?(artist_info) do
    ArtistInfo.wikipedia_description(artist_info) != nil ||
      ArtistInfo.wikipedia_summary(artist_info) != nil
  end

  defp discogs_available?(artist_info) do
    artist_info.discogs_data != nil &&
      (Map.get(artist_info.discogs_data, "profile_plaintext") != nil ||
         Map.get(artist_info.discogs_data, "profile") != nil)
  end

  defp wikipedia_artist_summary(artist_info) do
    description = ArtistInfo.wikipedia_description(artist_info) || ""
    summary = ArtistInfo.wikipedia_summary(artist_info) || ""
    truncated_summary = truncate_to_sentence(summary, 200)

    [description, truncated_summary]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(". ")
  end

  defp discogs_artist_summary(artist_info) do
    profile =
      Map.get(artist_info.discogs_data, "profile_plaintext") ||
        Map.get(artist_info.discogs_data, "profile") ||
        ""

    truncate_to_sentence(profile, 200)
  end

  @doc false
  def truncate_to_sentence(text, max_length) when byte_size(text) <= max_length, do: text

  def truncate_to_sentence(text, max_length) do
    truncated = String.slice(text, 0, max_length)

    case String.split(truncated, ~r/[.!?]\s/, include_captures: true) |> Enum.count() do
      count when count > 1 ->
        # Find the last sentence boundary within the limit
        truncated
        |> String.replace(~r/[^.!?]*$/, "")
        |> String.trim()
        |> case do
          "" -> String.trim(truncated)
          result -> result
        end

      _ ->
        String.trim(truncated)
    end
  end

  @doc """
  Finds similar records based on embedding similarity.

  ## Options

  - `:limit` - Maximum number of similar records to return (default: 10)
  - `:scope` - Filter by :collection or :wishlist (default: no filter)
  - `:max_distance` - Maximum cosine distance threshold (default: #{@max_distance}).
    Results with distance above this are excluded.

  ## Examples

      iex> find_similar("record-id-123", limit: 5)
      [%Record{}, ...]

      iex> find_similar("record-id-123", scope: :collection)
      [%Record{}, ...]
  """
  def find_similar(record_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    scope = Keyword.get(opts, :scope)
    max_distance = Keyword.get(opts, :max_distance, @max_distance)

    record = Records.get_record!(record_id)
    record_musicbrainz_id = record.musicbrainz_id

    case get_embedding(record_id) do
      {:ok, source_embedding} ->
        query =
          from re in RecordEmbedding,
            where: re.record_id != ^record_id,
            join: r in Record,
            on: r.id == re.record_id and r.musicbrainz_id != ^record_musicbrainz_id,
            order_by: selected_as(:similarity),
            select: %{
              record: r,
              similarity:
                vec_distance_cosine(re.embedding, vec_f32(source_embedding))
                |> selected_as(:similarity)
            },
            group_by: r.musicbrainz_id,
            having: vec_distance_cosine(re.embedding, vec_f32(source_embedding)) <= ^max_distance,
            limit: ^limit

        query = apply_scope_filter(query, scope)

        query
        |> Repo.all()

      {:error, :not_found} ->
        []
    end
  end

  @doc """
  Gets the embedding for a record.
  """
  def get_embedding(record_id) do
    case Repo.get_by(RecordEmbedding, record_id: record_id) do
      nil -> {:error, :not_found}
      embedding -> {:ok, embedding.embedding}
    end
  end

  def get_embedding_text(record_id) do
    case Repo.get_by(RecordEmbedding, record_id: record_id) do
      nil -> {:error, :not_found}
      embedding -> {:ok, embedding.text_representation}
    end
  end

  @doc """
  Stores an embedding for a record.
  """
  def store_embedding(record_id, embedding, text_representation) do
    attrs = %{
      record_id: record_id,
      embedding: embedding,
      text_representation: text_representation
    }

    %RecordEmbedding{}
    |> RecordEmbedding.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:embedding, :text_representation, :updated_at]},
      conflict_target: :record_id
    )
  end

  def generate_embedding_async(record) do
    meta = %{title: record.title, artists: Enum.map(record.artists, & &1.name)}
    params = %{record_id: record.id}

    params
    |> GenerateRecordEmbedding.new(meta: meta)
    |> Oban.insert()
  end

  def generate_all_embeddings_async do
    Record
    |> Repo.all()
    |> Enum.map(fn record ->
      meta = %{title: record.title, artists: Enum.map(record.artists, & &1.name)}
      params = %{record_id: record.id}

      params
      |> GenerateRecordEmbedding.new(meta: meta)
    end)
    |> Oban.insert_all()
    |> Enum.count()
  end

  # Private functions

  defp extract_year(nil), do: "Unknown"
  defp extract_year(""), do: "Unknown"

  defp extract_year(release_date) do
    case String.split(release_date, "-", parts: 2) do
      [year | _] -> year
      _ -> "Unknown"
    end
  end

  defp humanize_type(:album), do: "Album"
  defp humanize_type(:ep), do: "EP"
  defp humanize_type(:live), do: "Live"
  defp humanize_type(:compilation), do: "Compilation"
  defp humanize_type(:single), do: "Single"
  defp humanize_type(:other), do: "Other"
  defp humanize_type(_), do: "Unknown"

  defp apply_scope_filter(query, :collection) do
    from [re, r] in query, where: not is_nil(r.purchased_at)
  end

  defp apply_scope_filter(query, :wishlist) do
    from [re, r] in query, where: is_nil(r.purchased_at)
  end

  defp apply_scope_filter(query, _), do: query
end
