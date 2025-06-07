defmodule MusicLibrary.Records do
  @moduledoc """
  Provides function to work with records _irrespectively_ of their status as port of the collection or of the wishlist.
  """

  import Ecto.Query, warn: false

  alias MusicLibrary.Artists
  alias MusicLibrary.Records.{ArtistRecord, Cover, DominantColors, Record, SearchParser}
  alias MusicLibrary.{BackgroundRepo, Repo, Worker}

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
      :release_date
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

  defmacro order_alphabetically do
    quote do
      fragment(
        "unaccent(artists ->> '$[0].sort_name') COLLATE NOCASE ASC, unaccent(title) COLLATE NOCASE ASC"
      )
    end
  end

  defp build_search(initial_search, query, order \\ :alphabetical) do
    {:ok, parsed_query} = SearchParser.parse(query)

    search_with_order =
      case order do
        :alphabetical ->
          initial_search
          |> order_by(order_alphabetically())

        :purchase ->
          initial_search
          |> order_by([r], [
            {:desc, r.purchased_at},
            order_alphabetically()
          ])

        :insertion ->
          initial_search
          |> order_by([r], [
            {:desc, r.inserted_at},
            order_alphabetically()
          ])
      end

    Enum.reduce(parsed_query, search_with_order, fn
      {:artist, artist}, search ->
        search
        |> where(fragment("records_search_index match 'artists : ?*'", literal(^artist)))
        |> or_where(
          fragment("records_search_index match 'normalized_artists : ?*'", literal(^artist))
        )

      {:album, album}, search ->
        search
        |> where(fragment("records_search_index match 'title : ?*'", literal(^album)))
        |> or_where(
          fragment("records_search_index match 'normalized_title : ?*'", literal(^album))
        )

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
    selected_release_id = Keyword.get(opts, :selected_release_id, nil)

    with {:ok, release_group} <- MusicBrainz.get_release_group(musicbrainz_id),
         {:ok, release_group_with_releases} <- merge_releases(musicbrainz_id, release_group),
         {:ok, cover_data} <- get_cover_art_or_default(musicbrainz_id) do
      release_group_with_releases
      |> build_record_attrs(%{
        "cover_data" => cover_data,
        "format" => format,
        "purchased_at" => purchased_at,
        "selected_release_id" => selected_release_id
      })
      |> create_record()
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

  def get_last_listened_track(record) do
    record_id = record.id

    q =
      from r in fragment("records, json_each(records.release_ids)"),
        where: fragment("records.id = ?", ^record_id),
        select: r.value

    release_ids = Repo.all(q)
    main_artist_name = Record.main_artist(record).name
    record_title = record.title

    q =
      from t in LastFm.Track,
        where: fragment("? ->> '$.musicbrainz_id'", t.album) in ^release_ids,
        or_where:
          fragment("? ->> '$.title'", t.album) == ^record_title and
            fragment("? ->> '$.name'", t.artist) == ^main_artist_name,
        order_by: [desc: t.scrobbled_at_uts],
        limit: 1

    Repo.one(q)
  end

  def refresh_cover(record) do
    with {:ok, cover_data} <- MusicBrainz.get_cover_art({:url, record.cover_url}) do
      {:ok, thumb_data} = Cover.resize(cover_data)

      record
      |> Record.add_cover_data(thumb_data)
      |> Repo.update()
    end
  end

  def refresh_cover_async(record) do
    meta = %{title: record.title, artists: Enum.map(record.artists, & &1.name)}
    params = %{"id" => record.id}

    params
    |> Worker.RefreshCover.new(meta: meta)
    |> BackgroundRepo.insert()
  end

  def generate_dominant_colors(record) do
    with {:ok, colors} <- DominantColors.extract_dominant_colors(record.cover_data) do
      update_record(record, %{"dominant_colors" => colors})
    end
  end

  def generate_dominant_colors_async(record) do
    meta = %{title: record.title, artists: Enum.map(record.artists, & &1.name)}
    params = %{"id" => record.id}

    params
    |> Worker.GenerateDominantColors.new(meta: meta)
    |> BackgroundRepo.insert()
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

  def refresh_musicbrainz_data_async(record) do
    meta = %{title: record.title, artists: Enum.map(record.artists, & &1.name)}
    params = %{"id" => record.id}

    params
    |> Worker.RecordRefreshMusicBrainzData.new(meta: meta)
    |> BackgroundRepo.insert()
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
    with {:ok, record} <- do_create_record(attrs) do
      record
      |> Record.artist_ids()
      |> Enum.each(fn artist_id ->
        Artists.fetch_artist_info_async(artist_id)
      end)

      {:ok, record}
    end
  end

  defp do_create_record(attrs) do
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
    with {:ok, record} <- Repo.delete(record) do
      record
      |> Record.artist_ids()
      |> Enum.each(fn artist_id ->
        Artists.prune_artist_info_async(artist_id)
      end)

      {:ok, record}
    end
  end

  def change_record(%Record{} = record, attrs \\ %{}) do
    Record.changeset(record, attrs)
  end

  def subscribe(record_id) do
    Phoenix.PubSub.subscribe(MusicLibrary.PubSub, "records:#{record_id}")
  end

  def notify_update(record) do
    Phoenix.PubSub.broadcast(
      MusicLibrary.PubSub,
      "records:#{record.id}",
      {:update, record}
    )
  end
end
