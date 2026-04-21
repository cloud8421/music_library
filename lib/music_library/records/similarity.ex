defmodule MusicLibrary.Records.Similarity do
  @moduledoc """
  Functions for calculating and finding similar records based on embeddings.
  """

  import Ecto.Query
  import SqliteVec.Ecto.Query

  alias MusicLibrary.Artists
  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibrary.Notes
  alias MusicLibrary.Records
  alias MusicLibrary.Records.{Record, RecordEmbedding}
  alias MusicLibrary.Repo
  alias MusicLibrary.Worker.GenerateRecordEmbedding

  @max_distance Application.compile_env!(:music_library, :similarity)[:max_distance]

  @type find_opts :: [
          limit: pos_integer(),
          scope: :collection | :wishlist | nil,
          max_distance: float()
        ]

  @doc """
  Generates a text representation of a record for embedding generation.

  The representation includes:
  - Title
  - Artist names
  - Genres
  - Release year
  - Type (album, EP, etc.)
  - Per-artist blocks: name, country, disambiguation, Wikipedia summary (500 chars),
    Discogs profile excerpt (complementing Wikipedia when both available)
  - Last.fm community tags and similar artists (when stored)
  - User-written record notes (when present)
  """
  @spec text_representation(Record.t()) :: String.t()
  def text_representation(%Record{} = record) do
    artist_infos_map =
      record.artists
      |> Enum.map(& &1.musicbrainz_id)
      |> Artists.get_artist_infos()
      |> Map.new(&{&1.id, &1})

    artist_names = Record.artist_names(record)
    genres = Enum.join(record.genres, ", ")
    year = extract_year(record.release_date)
    type = humanize_type(record.type)
    note_text = record_note_text(record.musicbrainz_id)

    """
    Album: #{record.title}
    Artists: #{artist_names}
    Genres: #{genres}
    Released: #{year}
    Type: #{type}

    #{artist_blocks_summary(record.artists, artist_infos_map)}
    """
    |> String.trim()
    |> Kernel.<>(note_text)
  end

  defp artist_blocks_summary([], _artist_infos_map), do: ""

  defp artist_blocks_summary(artists, artist_infos_map) do
    artists
    |> Enum.map(fn artist ->
      artist_info = Map.get(artist_infos_map, artist.musicbrainz_id)
      artist_block(artist, artist_info)
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp artist_block(_artist, nil), do: ""

  defp artist_block(artist, artist_info) do
    country = safe_artist_country(artist_info)
    disambiguation = non_empty_string(Map.get(artist, :disambiguation))

    header_extras = [country, disambiguation] |> Enum.reject(&is_nil/1)

    header =
      if header_extras == [] do
        artist.name
      else
        "#{artist.name} (#{Enum.join(header_extras, ", ")})"
      end

    content = artist_content(artist_info)

    if content == "" do
      ""
    else
      "#{header}:\n#{content}"
    end
  end

  defp artist_content(artist_info) do
    has_wikipedia = wikipedia_available?(artist_info)
    has_discogs = discogs_available?(artist_info)

    base_content =
      cond do
        has_wikipedia && has_discogs ->
          wikipedia = wikipedia_artist_summary(artist_info)
          discogs_excerpt = discogs_artist_excerpt(artist_info)
          [wikipedia, discogs_excerpt] |> Enum.reject(&(&1 == "")) |> Enum.join("\n")

        has_wikipedia ->
          wikipedia_artist_summary(artist_info)

        has_discogs ->
          discogs_artist_summary(artist_info)

        true ->
          ""
      end

    tags_line = lastfm_tags_line(artist_info)
    similar_line = lastfm_similar_line(artist_info)
    extras = [tags_line, similar_line] |> Enum.reject(&(&1 == ""))

    if extras == [] do
      base_content
    else
      [base_content | extras] |> Enum.reject(&(&1 == "")) |> Enum.join("\n")
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
    truncated_summary = truncate_to_sentence(summary, 500)

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

  defp discogs_artist_excerpt(artist_info) do
    profile =
      Map.get(artist_info.discogs_data, "profile_plaintext") ||
        Map.get(artist_info.discogs_data, "profile") ||
        ""

    truncate_to_sentence(profile, 150)
  end

  defp lastfm_tags_line(artist_info) do
    tags = ArtistInfo.lastfm_tags(artist_info)

    if tags == [] do
      ""
    else
      "Tags: #{tags |> Enum.take(10) |> Enum.join(", ")}"
    end
  end

  defp lastfm_similar_line(artist_info) do
    similar = ArtistInfo.lastfm_similar_artists(artist_info)

    if similar == [] do
      ""
    else
      "Similar artists: #{similar |> Enum.take(5) |> Enum.join(", ")}"
    end
  end

  defp safe_artist_country(artist_info) do
    case artist_info.musicbrainz_data do
      %{"area" => %{"name" => name}} when is_binary(name) -> name
      _ -> nil
    end
  end

  defp record_note_text(nil), do: ""

  defp record_note_text(musicbrainz_id) do
    case Notes.get_note(:record, musicbrainz_id) do
      %{content: content} when is_binary(content) and content != "" ->
        "\n\nNotes: #{content}"

      _ ->
        ""
    end
  end

  defp non_empty_string(nil), do: nil
  defp non_empty_string(""), do: nil
  defp non_empty_string(s), do: s

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

  ## Examples

      iex> find_similar("record-id-123", limit: 5)
      [%Record{}, ...]

      iex> find_similar("record-id-123", scope: :collection)
      [%Record{}, ...]
  """
  @spec find_similar(String.t(), find_opts()) :: [map()]
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

  @spec get_embedding(String.t()) :: {:ok, binary()} | {:error, :not_found}
  def get_embedding(record_id) do
    case Repo.get_by(RecordEmbedding, record_id: record_id) do
      nil -> {:error, :not_found}
      embedding -> {:ok, embedding.embedding}
    end
  end

  @spec get_embedding_text(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_embedding_text(record_id) do
    case Repo.get_by(RecordEmbedding, record_id: record_id) do
      nil -> {:error, :not_found}
      embedding -> {:ok, embedding.text_representation}
    end
  end

  @spec store_embedding(String.t(), [float()], String.t()) ::
          {:ok, RecordEmbedding.t()} | {:error, Ecto.Changeset.t()}
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

  @spec generate_embedding(Record.t()) :: :noop | {:ok, RecordEmbedding.t()} | {:error, term()}
  def generate_embedding(%Record{} = record) do
    new_text = text_representation(record)

    case get_embedding_text(record.id) do
      {:ok, ^new_text} ->
        :noop

      _ ->
        with {:ok, embedding} <- OpenAI.embeddings(new_text) do
          store_embedding(record.id, embedding, new_text)
        end
    end
  end

  @spec generate_embedding_async(Record.t()) :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def generate_embedding_async(record) do
    meta = %{title: record.title, artists: Enum.map(record.artists, & &1.name)}
    params = %{record_id: record.id}

    params
    |> GenerateRecordEmbedding.new(meta: meta)
    |> Oban.insert()
  end

  @doc """
  Enqueues embedding regeneration for every record by the given artist.

  Used when upstream artist metadata (MusicBrainz/Wikipedia/Discogs/Last.fm)
  changes, so that each record's text representation — which embeds per-artist
  context — is re-computed.
  """
  @spec regenerate_artist_embeddings(String.t()) :: :ok
  def regenerate_artist_embeddings(musicbrainz_id) do
    musicbrainz_id
    |> Records.get_artist_records()
    |> Enum.each(&generate_embedding_async/1)
  end

  @spec generate_all_embeddings_async() :: non_neg_integer()
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
