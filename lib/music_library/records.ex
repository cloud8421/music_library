defmodule MusicLibrary.Records do
  import Ecto.Query, warn: false
  alias MusicLibrary.Repo

  alias MusicLibrary.Records.{MusicBrainz, Record}

  @fields [:id, :type, :format, :title, :release, :genres, :musicbrainz_id, :cover_hash]

  def list_records(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    q =
      from r in Record,
        order_by: [r.artists[0]["sort_name"], r.title],
        limit: ^limit,
        offset: ^offset,
        select: ^@fields

    Repo.all(q)
  end

  def search_records(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    q =
      from r in Record,
        where: like(r.title, ^"%#{query}%") or like(r.artists, ^"%#{query}%"),
        order_by: [r.artists[0]["sort_name"], r.title],
        limit: ^limit,
        offset: ^offset,
        select: ^@fields

    Repo.all(q)
  end

  def count_records do
    Repo.aggregate(Record, :count)
  end

  def count_records_by_format do
    q =
      from r in Record,
        group_by: r.format,
        select: {r.format, count(r.id)}

    Repo.all(q)
  end

  def search_records_count(query) do
    q =
      from r in Record,
        where: like(r.title, ^"%#{query}%") or like(r.artists, ^"%#{query}%")

    Repo.aggregate(q, :count)
  end

  def get_record!(id), do: Repo.get!(Record, id)

  def get_latest_record! do
    q =
      from r in Record,
        order_by: [desc: r.inserted_at],
        limit: 1,
        select: ^@fields

    Repo.one!(q)
  end

  def get_cover!(id) do
    q =
      from r in Record,
        where: r.id == ^id,
        select: %{cover_data: r.cover_data, cover_hash: r.cover_hash}

    Repo.one!(q)
  end

  def search_release_group(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    MusicBrainz.search_release_group(query, limit: limit, offset: offset)
  end

  def import_from_musicbrainz(musicbrainz_id, opts \\ []) do
    with format = Keyword.get(opts, :format, "cd"),
         {:ok, release_group} <- MusicBrainz.get_release_group(musicbrainz_id),
         {:ok, cover_data} <- MusicBrainz.get_cover_art(musicbrainz_id),
         record_params = build_record_params(release_group, cover_data, format) do
      create_record(record_params)
    else
      error -> error
    end
  end

  defp build_record_params(release_group, cover_data, format) do
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
      "title" => release_group["title"],
      "artists" => artists_attrs,
      "release" => release_group["first-release-date"],
      "type" => parse_subtype(release_group["primary-type"]),
      "format" => format,
      "genres" => Enum.map(release_group["genres"], fn g -> g["name"] end),
      "cover_url" => "https://coverartarchive.org/release-group/#{musicbrainz_id}/front",
      "cover_data" => cover_data
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
end
