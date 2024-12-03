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

    search =
      initial_search
      |> build_search(query)
      |> limit(^limit)
      |> offset(^offset)
      |> select(^essential_fields())

    Repo.all(search)
  end

  def search_records_count(initial_search, query) do
    search = build_search(initial_search, query)

    Repo.aggregate(search, :count)
  end

  defp build_search(initial_search, query) do
    {:ok, parsed_query} = SearchParser.parse(query)

    search_with_order =
      initial_search
      |> order_by(
        fragment(
          "json_extract(artists, '$[0].sort_name') COLLATE NOCASE ASC, title COLLATE NOCASE ASC"
        )
      )

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

  def get_artist!(musicbrainz_id) do
    q =
      from ar in ArtistRecord,
        where: ar.musicbrainz_id == ^musicbrainz_id,
        limit: 1,
        select: ar.artist

    Repo.one!(q)
  end

  def get_artist_records(musicbrainz_id) do
    q =
      from r in Record,
        join: ar in ArtistRecord,
        on: r.id == ar.record_id and ar.musicbrainz_id == ^musicbrainz_id,
        select: ^essential_fields()

    Repo.all(q)
  end

  def get_artist_info(musicbrainz_id) do
    last_fm().get_artist_info(musicbrainz_id, last_fm_config())
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
    musicbrainz().search_release_group(query, limit: limit, offset: offset)
  end

  def import_from_musicbrainz_release(musicbrainz_id, opts \\ []) do
    case musicbrainz().get_release(musicbrainz_id) do
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
         {:ok, release_group} <- musicbrainz().get_release_group(musicbrainz_id),
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

  defp get_cover_art_or_default(musicbrainz_id) do
    case musicbrainz().get_cover_art({:musicbrainz_id, musicbrainz_id}) do
      {:error, :cover_not_available} -> {:ok, Record.fallback_cover_data()}
      {:ok, cover_data} -> Cover.resize(cover_data)
    end
  end

  def refresh_cover(record) do
    with {:ok, cover_data} <- musicbrainz().get_cover_art({:url, record.cover_url}) do
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
    with {:ok, data} <- musicbrainz().get_release_group(record.musicbrainz_id) do
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

  defp musicbrainz do
    Application.get_env(:music_library, :musicbrainz, MusicBrainz.APIImpl)
  end

  defp last_fm do
    Application.get_env(:music_library, :last_fm, LastFm.APIImpl)
  end

  defp last_fm_config, do: LastFm.Config.resolve(:music_library)
end
