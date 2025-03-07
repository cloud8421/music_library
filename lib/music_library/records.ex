defmodule MusicLibrary.Records do
  @moduledoc """
  Provides function to work with records _irrespectively_ of their status as port of the collection or of the wishlist.
  """

  import Ecto.Query, warn: false

  alias MusicLibrary.Records.{ArtistRecord, Cover, Record, SearchParser}
  alias MusicLibrary.Repo

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

  def get_release_status(release_id, format) do
    q =
      from r in fragment("records, json_each(records.release_ids)"),
        where: fragment("records.format = ?", ^format) and r.value == ^release_id,
        select: %{
          record_id: fragment("records.id"),
          purchased_at: fragment("records.purchased_at")
        }

    case Repo.one(q) do
      nil -> :new
      %{record_id: record_id, purchased_at: nil} -> {:wishlisted, record_id}
      %{record_id: record_id} -> {:collected, record_id}
    end
  end

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

  def import_from_musicbrainz_release(musicbrainz_id, opts \\ []) do
    case MusicBrainz.get_release(musicbrainz_id) do
      {:ok, release} ->
        release_group_id = release["release-group"]["id"]
        import_from_musicbrainz_release_group(release_group_id, opts)

      error ->
        error
    end
  end

  def import_from_musicbrainz_release_group(musicbrainz_id, opts \\ []) do
    format = Keyword.get(opts, :format, "cd")
    purchased_at = Keyword.get(opts, :purchased_at)

    with {:ok, release_group} <- MusicBrainz.get_release_group(musicbrainz_id),
         {:ok, release_group_with_releases} <- merge_releases(musicbrainz_id, release_group),
         {:ok, cover_data} <- get_cover_art_or_default(musicbrainz_id) do
      release_group_with_releases
      |> build_record_attrs(%{
        "cover_data" => cover_data,
        "format" => format,
        "purchased_at" => purchased_at
      })
      |> create_record()
    else
      error -> error
    end
  end

  def populate_genres(record) do
    artists = Enum.map_join(record.artists, ",", fn a -> a.name end)

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
    case MusicBrainz.get_cover_art({:musicbrainz_id, musicbrainz_id}) do
      {:error, :cover_not_available} -> {:ok, Cover.fallback_data()}
      {:ok, cover_data} -> Cover.resize(cover_data)
    end
  end

  def refresh_cover(record) do
    with {:ok, cover_data} <- MusicBrainz.get_cover_art({:url, record.cover_url}) do
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
    with {:ok, data} <- MusicBrainz.get_release_group(record.musicbrainz_id),
         {:ok, data_with_releases} <- merge_releases(record.musicbrainz_id, data) do
      record
      |> Record.add_musicbrainz_data(data_with_releases)
      |> Repo.update()
    end
  end

  defp merge_releases(musicbrainz_id, musicbrainz_data) do
    with {:ok, releases} <- stream_releases(musicbrainz_id) do
      {:ok, Map.put(musicbrainz_data, "releases", releases)}
    end
  end

  defp stream_releases(musicbrainz_id) do
    do_stream_releases(musicbrainz_id, [], 0)
  end

  defp do_stream_releases(musicbrainz_id, releases, offset) do
    limit = 100
    opts = [limit: limit, offset: offset]

    with {:ok, data} <- MusicBrainz.get_releases(musicbrainz_id, opts) do
      %{"releases" => new_releases} = data

      if Enum.count(new_releases) < limit do
        {:ok, releases ++ new_releases}
      else
        do_stream_releases(musicbrainz_id, releases ++ new_releases, offset + 100)
      end
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
end
