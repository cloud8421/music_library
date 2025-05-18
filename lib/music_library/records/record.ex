defmodule MusicLibrary.Records.Record do
  use Ecto.Schema
  import Ecto.Changeset

  alias MusicBrainz.{Release, ReleaseGroup}
  alias MusicLibrary.Records.{Artist, Cover}

  @formats [:cd, :backup, :vinyl, :blu_ray, :dvd, :multi]
  @types [:album, :ep, :live, :compilation, :single, :other]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "records" do
    field :type, Ecto.Enum, values: @types
    field :format, Ecto.Enum, values: @formats
    field :title, :string
    field :cover_url, :string
    field :cover_data, :binary
    field :cover_hash, :string
    field :musicbrainz_id, Ecto.UUID
    field :musicbrainz_data, :map, default: %{}
    field :genres, {:array, :string}
    field :release_date, :string
    field :purchased_at, :utc_datetime
    field :selected_release_id, :string
    field :release_ids, {:array, :string}, default: []
    field :included_release_group_ids, {:array, :string}, default: []

    embeds_many :artists, Artist

    timestamps(type: :utc_datetime)
  end

  def artist_names(record) do
    Enum.map_join(record.artists, ", ", fn artist -> artist.name end)
  end

  def artist_ids(record) do
    Enum.map(record.artists, fn artist -> artist.musicbrainz_id end)
  end

  def formats, do: @formats
  def types, do: @types

  def included_release_groups(record) do
    record.musicbrainz_data
    |> ReleaseGroup.included_release_groups()
    |> Enum.filter(fn rg -> rg.id in record.included_release_group_ids end)
  end

  def included_release_groups_count(record) do
    Enum.count(record.included_release_group_ids)
  end

  def release_count(record) do
    Enum.count(record.release_ids)
  end

  def released?(%{release_date: nil}, _current_day), do: true

  def released?(record, current_day) do
    case Date.from_iso8601(record.release_date) do
      {:ok, release_date} ->
        Date.compare(current_day, release_date) != :lt

      _error ->
        # When a release date cannot be parsed it's normally because the record
        # is old and information is not specific, so we can err on the side of assuming
        # it's been released.
        true
    end
  end

  def releases(record) do
    record.musicbrainz_data
    |> ReleaseGroup.releases()
    |> Enum.map(&Release.from_api_response/1)
    |> Enum.sort_by(fn r -> {r.date, r.country} end, :desc)
  end

  def selected_release(record) do
    record
    |> releases()
    |> Enum.find(fn release -> release.id == record.selected_release_id end)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :type,
      :format,
      :title,
      :musicbrainz_id,
      :musicbrainz_data,
      :release_date,
      :genres,
      :release_ids,
      :selected_release_id,
      :included_release_group_ids,
      :cover_url,
      :cover_data,
      :purchased_at
    ])
    |> cast_embed(:artists)
    |> validate_required([:type, :title, :musicbrainz_id, :genres])
    |> unique_constraint(:musicbrainz_id, name: "records_musicbrainz_id_format_index")
    |> generate_cover_hash()
    |> update_release_ids()
    |> update_included_release_group_ids()
  end

  def add_genres(record, genres) do
    change(record, genres: genres)
  end

  def add_cover_data(record, cover_data) do
    record
    |> change(cover_data: cover_data)
    |> generate_cover_hash()
  end

  def add_musicbrainz_data(record, musicbrainz_data) do
    record
    |> change(musicbrainz_data: musicbrainz_data)
    |> update_release_ids()
    |> update_included_release_group_ids()
  end

  def generate_cover_hash(%__MODULE__{cover_data: cover_data} = record) do
    change(record, cover_hash: Cover.hash(cover_data))
  end

  def generate_cover_hash(changeset) do
    case get_change(changeset, :cover_data) do
      nil ->
        changeset

      cover_data ->
        put_change(changeset, :cover_hash, Cover.hash(cover_data))
    end
  end

  defp update_release_ids(changeset) do
    case get_change(changeset, :musicbrainz_data) do
      nil ->
        changeset

      musicbrainz_data ->
        put_change(changeset, :release_ids, ReleaseGroup.release_ids(musicbrainz_data))
    end
  end

  defp update_included_release_group_ids(changeset) do
    case get_change(changeset, :musicbrainz_data) do
      nil ->
        changeset

      musicbrainz_data ->
        put_change(
          changeset,
          :included_release_group_ids,
          ReleaseGroup.included_release_group_ids(musicbrainz_data)
        )
    end
  end

  def attrs_from_release_group(release_group) do
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
      "release_date" => release_group["first-release-date"],
      "type" => parse_subtype(release_group["primary-type"]),
      "genres" => Enum.map(release_group["genres"], fn g -> g["name"] end),
      "release_ids" => Enum.map(release_group["releases"], fn r -> r["id"] end),
      "cover_url" => "https://coverartarchive.org/release-group/#{musicbrainz_id}/front"
    }
  end

  defp parse_subtype("Album"), do: :album
  defp parse_subtype("EP"), do: :ep
  defp parse_subtype("Live"), do: :live
  defp parse_subtype("Compilation"), do: :compilation
  defp parse_subtype("Single"), do: :single
  defp parse_subtype(_), do: :other

  @doc """
  Format a release date in a conventional format.

  Release dates as returned by MusicBrainz have different levels of precision,
  and can be nil or empty string.

      iex> alias MusicLibrary.Records.Record
      iex> Record.format_release_date(nil)
      "N/A"
      iex> Record.format_release_date("")
      "N/A"
      iex> Record.format_release_date("2021")
      "2021"
      iex> Record.format_release_date("2021-12")
      "12/2021"
      iex> Record.format_release_date("2021-12-23")
      "23/12/2021"
  """
  @spec format_release_date(String.t() | nil) :: String.t()
  def format_release_date(nil), do: "N/A"

  def format_release_date(release_date) do
    case String.split(release_date, "-", trim: true) do
      [] -> "N/A"
      [year] -> year
      [year, month] -> "#{month}/#{year}"
      [year, month, day] -> "#{day}/#{month}/#{year}"
    end
  end

  def format_as_date(dt) do
    Calendar.strftime(dt, "%d/%m/%Y")
  end
end
