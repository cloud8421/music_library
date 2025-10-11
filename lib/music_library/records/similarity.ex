defmodule MusicLibrary.Records.Similarity do
  @moduledoc """
  Functions for calculating and finding similar records based on embeddings.
  """

  import Ecto.Query

  alias MusicLibrary.Records.{Record, RecordEmbedding}
  alias MusicLibrary.Repo

  @doc """
  Generates a text representation of a record for embedding generation.

  The representation includes:
  - Title
  - Artist names
  - Genres
  - Release year
  - Type (album, EP, etc.)
  """
  def text_representation(%Record{} = record) do
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
    """
    |> String.trim()
  end

  @doc """
  Finds similar records based on embedding similarity.

  ## Options

  - `:limit` - Maximum number of similar records to return (default: 10)
  - `:min_similarity` - Minimum similarity score (0.0 to 1.0, default: 0.0)
  - `:scope` - Filter by :collection or :wishlist (default: no filter)

  ## Examples

      iex> find_similar("record-id-123", limit: 5)
      [%Record{}, ...]

      iex> find_similar("record-id-123", min_similarity: 0.7, scope: :collection)
      [%Record{}, ...]
  """
  def find_similar(record_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_similarity = Keyword.get(opts, :min_similarity, 0.0)
    scope = Keyword.get(opts, :scope)

    with {:ok, source_embedding} <- get_embedding(record_id),
         similar_records <- calculate_similarities(source_embedding, record_id, scope) do
      similar_records
      |> Enum.filter(fn {_record, similarity} -> similarity >= min_similarity end)
      |> Enum.take(limit)
      |> Enum.map(fn {record, similarity} -> {record, Float.round(similarity, 4)} end)
    else
      {:error, :not_found} -> []
    end
  end

  @doc """
  Calculates cosine similarity between two embedding vectors.

  Returns a float between -1.0 and 1.0, where:
  - 1.0 = identical vectors
  - 0.0 = orthogonal vectors
  - -1.0 = opposite vectors
  """
  def cosine_similarity(vec_a, vec_b) when is_list(vec_a) and is_list(vec_b) do
    if length(vec_a) != length(vec_b) do
      raise ArgumentError, "Vectors must have the same length"
    end

    dot_product =
      Enum.zip(vec_a, vec_b)
      |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)

    magnitude_a = calculate_magnitude(vec_a)
    magnitude_b = calculate_magnitude(vec_b)

    if magnitude_a == 0.0 or magnitude_b == 0.0 do
      0.0
    else
      dot_product / (magnitude_a * magnitude_b)
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

  defp calculate_magnitude(vector) do
    vector
    |> Enum.reduce(0.0, fn x, acc -> acc + x * x end)
    |> :math.sqrt()
  end

  defp calculate_similarities(source_embedding, source_record_id, scope) do
    query =
      from re in RecordEmbedding,
        where: re.record_id != ^source_record_id,
        join: r in Record,
        on: r.id == re.record_id,
        select: {r, re.embedding}

    query = apply_scope_filter(query, scope)

    query
    |> Repo.all()
    |> Enum.map(fn {record, embedding} ->
      similarity = cosine_similarity(source_embedding, embedding)
      {record, similarity}
    end)
    |> Enum.sort_by(fn {_record, similarity} -> similarity end, :desc)
  end

  defp apply_scope_filter(query, :collection) do
    from [re, r] in query, where: not is_nil(r.purchased_at)
  end

  defp apply_scope_filter(query, :wishlist) do
    from [re, r] in query, where: is_nil(r.purchased_at)
  end

  defp apply_scope_filter(query, _), do: query
end
