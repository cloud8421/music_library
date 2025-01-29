defmodule MusicLibrary.Records.Record do
  use Ecto.Schema
  import Ecto.Changeset

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
    field :release, :string
    field :purchased_at, :utc_datetime
    field :release_ids, {:array, :string}, default: []
    field :included_release_group_ids, {:array, :string}, default: []

    embeds_many :artists, Artist

    timestamps(type: :utc_datetime)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :type,
      :format,
      :title,
      :musicbrainz_id,
      :musicbrainz_data,
      :release,
      :genres,
      :release_ids,
      :included_release_group_ids,
      :cover_url,
      :cover_data,
      :purchased_at
    ])
    |> cast_embed(:artists)
    |> validate_required([:type, :title, :musicbrainz_id, :release, :genres])
    |> unique_constraint(:musicbrainz_id, name: "records_musicbrainz_id_format_index")
    |> generate_cover_hash()
    |> update_release_ids()
    |> update_included_release_group_ids()
  end

  def child_release_groups(record) do
    record.musicbrainz_data
    |> Map.get("relations", [])
    |> Enum.filter(fn relation ->
      relation["target-type"] == "release_group" and
        relation["type"] == "included in" and
        relation["direction"] == "backward"
    end)
    |> Enum.map(fn relation ->
      MusicBrainz.ReleaseGroup.from_api_response(relation["release_group"])
    end)
  end

  def child_release_groups_count(record) do
    Enum.count(record.included_release_group_ids)
  end

  def add_artists(record, artists_attrs) do
    record
    |> change()
    |> put_embed(:artists, artists_attrs)
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

  def update_release_ids(record = %__MODULE__{musicbrainz_data: musicbrainz_data}) do
    release_ids = Enum.map(musicbrainz_data["releases"], fn r -> r["id"] end)

    record
    |> change(release_ids: release_ids)
  end

  def update_release_ids(changeset) do
    case get_change(changeset, :musicbrainz_data) do
      nil ->
        changeset

      musicbrainz_data ->
        release_ids = Enum.map(musicbrainz_data["releases"], fn r -> r["id"] end)
        put_change(changeset, :release_ids, release_ids)
    end
  end

  def update_included_release_group_ids(record = %__MODULE__{musicbrainz_data: musicbrainz_data}) do
    included_release_group_ids = extract_included_release_group_ids(musicbrainz_data)

    record
    |> change(included_release_group_ids: included_release_group_ids)
  end

  def update_included_release_group_ids(changeset) do
    case get_change(changeset, :musicbrainz_data) do
      nil ->
        changeset

      musicbrainz_data ->
        included_release_group_ids = extract_included_release_group_ids(musicbrainz_data)

        put_change(changeset, :included_release_group_ids, included_release_group_ids)
    end
  end

  defp extract_included_release_group_ids(musicbrainz_data) do
    musicbrainz_data
    |> Map.get("relations", [])
    |> Enum.filter(fn relation ->
      relation["target-type"] == "release_group" and
        relation["type"] == "included in" and
        relation["direction"] == "backward"
    end)
    |> Enum.map(fn relation -> relation["release_group"]["id"] end)
  end

  def generate_cover_hash(record = %__MODULE__{cover_data: cover_data}) do
    record
    |> change()
    |> put_change(:cover_hash, Cover.hash(cover_data))
  end

  def generate_cover_hash(changeset) do
    case get_change(changeset, :cover_data) do
      nil ->
        changeset

      cover_data ->
        put_change(changeset, :cover_hash, Cover.hash(cover_data))
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
      "release" => release_group["first-release-date"],
      "type" => parse_subtype(release_group["primary-type"]),
      "genres" => Enum.map(release_group["genres"], fn g -> g["name"] end),
      "release_ids" => Enum.map(release_group["releases"], fn r -> r["id"] end),
      "cover_url" => "https://coverartarchive.org/release-group/#{musicbrainz_id}/front"
    }
  end

  def formats, do: @formats
  def types, do: @types

  def formats_with_labels do
    Enum.map(@formats, fn f -> {format_long_label(f), f} end)
  end

  def types_with_labels do
    Enum.map(@types, fn t -> {type_long_label(t), t} end)
  end

  def format_long_label(:cd), do: "CD"
  def format_long_label(:backup), do: "Backup"
  def format_long_label(:vinyl), do: "Vinyl"
  def format_long_label(:blu_ray), do: "Blu-ray"
  def format_long_label(:dvd), do: "DVD"
  def format_long_label(:multi), do: "Multi"

  def type_long_label(:album), do: "Album"
  def type_long_label(:ep), do: "EP"
  def type_long_label(:live), do: "Live"
  def type_long_label(:compilation), do: "Comp"
  def type_long_label(:single), do: "Single"
  def type_long_label(:other), do: "Other"

  def format_release(nil), do: "N/A"

  def format_release(release) do
    case String.split(release, "-") do
      [] -> "N/A"
      [year] -> year
      [year, month] -> "#{month}/#{year}"
      [year, month, day] -> "#{day}/#{month}/#{year}"
    end
  end

  def released?(record, current_day) do
    case Date.from_iso8601(record.release) do
      {:ok, release_date} ->
        Date.compare(current_day, release_date) != :lt

      _error ->
        false
    end
  end

  def format_as_date(purchased_at) do
    "#{purchased_at.day}/#{purchased_at.month}/#{purchased_at.year}"
  end

  defp parse_subtype("Album"), do: :album
  defp parse_subtype("EP"), do: :ep
  defp parse_subtype("Live"), do: :live
  defp parse_subtype("Compilation"), do: :compilation
  defp parse_subtype("Single"), do: :single
  defp parse_subtype(_), do: :other
end
