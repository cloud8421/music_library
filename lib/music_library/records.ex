defmodule MusicLibrary.Records do
  import Ecto.Query, warn: false
  alias MusicLibrary.Repo

  alias MusicLibrary.Records.{Record, SearchParser}

  @fields [:id, :type, :artists, :format, :title, :release, :genres, :musicbrainz_id, :cover_hash]

  def minimal_record_fields, do: @fields

  def search_records(initial_search, query, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.fetch!(opts, :offset)

    search =
      initial_search
      |> build_search(query)
      |> limit(^limit)
      |> offset(^offset)
      |> select(^@fields)

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
        search |> where([r], like(r.artists, ^"%#{artist}%"))

      {:album, album}, search ->
        search |> where([r], like(r.title, ^"%#{album}%"))

      {:mbid, mbid}, search ->
        search |> where([r], r.musicbrainz_id == ^mbid or like(r.artists, ^"%#{mbid}%"))

      {:format, format}, search ->
        search |> where([r], r.format == ^format)

      {:type, type}, search ->
        search |> where([r], r.type == ^type)

      {:query, raw_query}, search ->
        search
        |> where(
          [r],
          like(r.title, ^"%#{raw_query}%") or like(r.artists, ^"%#{raw_query}%")
        )
    end)
  end

  def get_record!(id), do: Repo.get!(Record, id)

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
         {:ok, cover_data} <- musicbrainz().get_cover_art(musicbrainz_id),
         record_params = build_record_params(release_group, cover_data, format, purchased_at) do
      create_record(record_params)
    else
      error -> error
    end
  end

  defp build_record_params(release_group, cover_data, format, purchased_at) do
    musicbrainz_id = release_group["id"]

    artists_attrs =
      release_group
      |> get_in(["artist-credit", Access.all(), "artist"])
      |> Enum.map(fn artist ->
        %{
          name: artist["name"],
          musicbrainz_id: artist["id"],
          sort_name: artist["sort-name"],
          disambiguation: artist["disambiguation"]
        }
      end)

    %{
      "musicbrainz_id" => musicbrainz_id,
      "musicbrainz_data" => release_group,
      "title" => release_group["title"],
      "artists" => artists_attrs,
      "release" => release_group["first-release-date"],
      "type" => parse_subtype(release_group["primary-type"]),
      "format" => format,
      "genres" => Enum.map(release_group["genres"], fn g -> g["name"] end),
      "cover_url" => "https://coverartarchive.org/release-group/#{musicbrainz_id}/front",
      "cover_data" => cover_data,
      "purchased_at" => purchased_at
    }
  end

  defp parse_subtype("Album"), do: :album
  defp parse_subtype("EP"), do: :ep
  defp parse_subtype("Live"), do: :live
  defp parse_subtype("Compilation"), do: :compilation
  defp parse_subtype("Single"), do: :single
  defp parse_subtype(_), do: :other

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
end
