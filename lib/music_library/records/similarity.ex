defmodule MusicLibrary.Records.Similarity do
  @moduledoc """
  Functions for calculating and finding similar records based on embeddings.
  """

  import Ecto.Query
  import(SqliteVec.Ecto.Query)

  alias MusicLibrary.Records
  alias MusicLibrary.Records.{Record, RecordEmbedding}
  alias MusicLibrary.Repo
  alias MusicLibrary.Worker.GenerateRecordEmbedding

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
    scope = Keyword.get(opts, :scope)

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
    |> Oban.insert!()
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
