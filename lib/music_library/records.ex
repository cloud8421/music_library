defmodule MusicLibrary.Records do
  @moduledoc """
  Provides function to work with records _irrespectively_ of their status as port of the collection or of the wishlist.
  """

  import Ecto.Query, warn: false
  alias MusicLibrary.Repo

  alias MusicLibrary.Records.{ArtistRecord, Cover, Record, SearchParser}

  def essential_fields do
    [
      :id,
      :type,
      :format,
      :title,
      :artists,
      :genres,
      :musicbrainz_id,
      :purchased_at,
      :release_ids,
      :included_release_group_ids,
      :cover_hash,
      :release
    ]
  end

  def search_records(initial_search, query, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.fetch!(opts, :offset)
    order = Keyword.fetch!(opts, :order)

    search =
      initial_search
      |> build_search(query, order)
      |> limit(^limit)
      |> offset(^offset)
      |> select(^essential_fields())

    Repo.all(search)
  end

  def search_records_count(initial_search, query) do
    search = build_search(initial_search, query)

    Repo.aggregate(search, :count)
  end

  defp build_search(initial_search, query, order \\ :alphabetical) do
    {:ok, parsed_query} = SearchParser.parse(query)

    search_with_order =
      case order do
        :alphabetical ->
          initial_search
          |> order_by(
            fragment(
              "unaccent(json_extract(artists, '$[0].sort_name')) COLLATE NOCASE ASC, unaccent(title) COLLATE NOCASE ASC"
            )
          )

        :purchase ->
          initial_search
          |> order_by([r], {:desc, r.purchased_at})
      end

    Enum.reduce(parsed_query, search_with_order, fn
      {:artist, artist}, search ->
        search
        |> where(fragment("records_search_index match 'artists : ?*'", literal(^artist)))

      {:album, album}, search ->
        search
        |> where(fragment("records_search_index match 'title : ?*'", literal(^album)))

      {:genre, genre}, search ->
        search
        |> where(fragment("records_search_index match 'genres : ?*'", literal(^genre)))

      {:mbid, mbid}, search ->
        search
        |> where(fragment("records_search_index = '?*'", literal(^mbid)))

      {:format, format}, search ->
        search |> where([r], r.format == ^format)

      {:type, type}, search ->
        search |> where([r], r.type == ^type)

      {:query, ""}, search ->
        search

      {:query, raw_query}, search ->
        search
        |> where(fragment("records_search_index = '?*'", literal(^raw_query)))
    end)
  end

  def get_record!(id), do: Repo.get!(Record, id)

  def get_artist_records(musicbrainz_id) do
    q =
      from r in Record,
        join: ar in ArtistRecord,
        on: r.id == ar.record_id and ar.musicbrainz_id == ^musicbrainz_id,
        select: ^essential_fields()

    Repo.all(q)
  end

  def get_cover(id) do
    q =
      from r in Record,
        where: r.id == ^id,
        select: %{cover_data: r.cover_data, cover_hash: r.cover_hash}

    Repo.one(q)
  end

  def search_release_group(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    music_brainz_config().api.search_release_group(
      query,
      [limit: limit, offset: offset],
      music_brainz_config()
    )
  end

  def import_from_musicbrainz_release(musicbrainz_id, opts \\ []) do
    case music_brainz_config().api.get_release(musicbrainz_id, music_brainz_config()) do
      {:ok, release} ->
        release_group_id = release["release-group"]["id"]
        import_from_musicbrainz_release_group(release_group_id, opts)

      error ->
        error
    end
  end

  def import_from_musicbrainz_release_group(musicbrainz_id, opts \\ []) do
    with format = Keyword.get(opts, :format, "cd"),
         purchased_at = Keyword.get(opts, :purchased_at),
         {:ok, release_group} <-
           music_brainz_config().api.get_release_group(musicbrainz_id, music_brainz_config()),
         {:ok, cover_data} <- get_cover_art_or_default(musicbrainz_id),
         record_attrs =
           build_record_attrs(release_group, %{
             "cover_data" => cover_data,
             "format" => format,
             "purchased_at" => purchased_at
           }) do
      create_record(record_attrs)
    else
      error -> error
    end
  end

  def populate_genres(record) do
    artists =
      record.artists
      |> Enum.map(fn a -> a.name end)
      |> Enum.join(",")

    completion = %OpenAI.Completion{
      content: """
      Provide a list of music genres applicable to the album "#{record.title}" by #{artists}.

      Limit the list to 5 genres, ordered by decreasing specificity, all lowercase.

      Return a response in JSON format, without any code block or formatting around it.
      """
    }

    {:ok, response} = OpenAI.gpt(completion)

    record
    |> Record.add_genres(response["genres"])
    |> Repo.update()
  end

  defp get_cover_art_or_default(musicbrainz_id) do
    case music_brainz_config().api.get_cover_art(
           {:musicbrainz_id, musicbrainz_id},
           music_brainz_config()
         ) do
      {:error, :cover_not_available} -> {:ok, Cover.fallback_data()}
      {:ok, cover_data} -> Cover.resize(cover_data)
    end
  end

  def refresh_cover(record) do
    with {:ok, cover_data} <-
           music_brainz_config().api.get_cover_art(
             {:url, record.cover_url},
             music_brainz_config()
           ) do
      {:ok, thumb_data} = Cover.resize(cover_data)

      record
      |> Record.add_cover_data(thumb_data)
      |> Repo.update()
    end
  end

  def resize_cover(record) do
    {:ok, thumb_data} = Cover.resize(record.cover_data)

    record
    |> Record.add_cover_data(thumb_data)
    |> Repo.update()
  end

  def refresh_musicbrainz_data(record) do
    with {:ok, data} <-
           music_brainz_config().api.get_release_group(
             record.musicbrainz_id,
             music_brainz_config()
           ) do
      record
      |> Record.add_musicbrainz_data(data)
      |> Repo.update()
    end
  end

  defp build_record_attrs(release_group, attrs) do
    release_group
    |> Record.attrs_from_release_group()
    |> Map.merge(attrs)
  end

  def create_record(attrs \\ %{}) do
    %Record{}
    |> Record.changeset(attrs)
    |> Repo.insert()
  end

  def update_record(%Record{} = record, attrs) do
    record
    |> Record.changeset(attrs)
    |> Repo.update()
  end

  def delete_record(%Record{} = record) do
    Repo.delete(record)
  end

  def change_record(%Record{} = record, attrs \\ %{}) do
    Record.changeset(record, attrs)
  end

  defp music_brainz_config, do: MusicBrainz.Config.resolve(:music_library)
end
