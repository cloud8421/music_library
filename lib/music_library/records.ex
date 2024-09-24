defmodule MusicLibrary.Records do
  import Ecto.Query, warn: false
  alias MusicLibrary.Repo

  alias MusicLibrary.Records.{MusicBrainz, Record}

  def list_records(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    q =
      from r in Record,
        order_by: [r.artists[0]["sort_name"], r.title],
        limit: ^limit,
        offset: ^offset

    Repo.all(q)
  end

  def count_records do
    Repo.aggregate(Record, :count)
  end

  def get_record!(id), do: Repo.get!(Record, id)

  def get_image!(id) do
    q =
      from r in Record,
        where: r.id == ^id,
        select: r.image_data

    Repo.one!(q)
  end

  def import_from_musicbrainz(musicbrainz_id) do
    with {:ok, release_group} <- MusicBrainz.get_release_group(musicbrainz_id),
         {:ok, image_data} <- MusicBrainz.get_cover_art(musicbrainz_id),
         record_params = build_record_params(release_group, image_data) do
      create_record(record_params)
    else
      error -> error
    end
  end

  defp build_record_params(release_group, image_data) do
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
      "year" => parse_year(release_group["first-release-date"]),
      "type" => parse_subtype(release_group["primary-type"]),
      "genres" => Enum.map(release_group["genres"], fn g -> g["name"] end),
      "image_url" => "https://coverartarchive.org/release-group/#{musicbrainz_id}/front",
      "image_data" => image_data
    }
  end

  defp parse_year(iso_date) when is_binary(iso_date) do
    case Date.from_iso8601(iso_date) do
      {:ok, date} ->
        date.year

      _error ->
        {year, _rest} = Integer.parse(iso_date)
        {:ok, year}
    end
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
