defmodule MusicLibrary.Records.Record do
  use Ecto.Schema
  import Ecto.Changeset

  @formats [:cd, :vinyl, :blu_ray, :dvd, :multi]
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
    field :musicbrainz_data, :map
    field :genres, {:array, :string}
    field :release, :string

    embeds_many :artists, Artist do
      field :name, :string
      field :sort_name, :string
      field :disambiguation, :string
      field :musicbrainz_id, Ecto.UUID
    end

    timestamps(type: :utc_datetime)
  end

  @doc false
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
      :cover_url,
      :cover_data
    ])
    |> cast_embed(:artists, with: &artist_changeset/2)
    |> generate_cover_hash()
    |> validate_required([:type, :title, :musicbrainz_id, :release, :genres])
  end

  @doc false
  def artist_changeset(artist, attrs) do
    artist
    |> cast(attrs, [:name, :sort_name, :disambiguation, :musicbrainz_id])
    |> validate_required([:name, :sort_name, :musicbrainz_id])
  end

  def add_artists(record, artists_attrs) do
    record
    |> change()
    |> put_embed(:artists, artists_attrs)
  end

  def add_cover_data(record, cover_data) do
    record
    |> change(cover_data: cover_data)
    |> generate_cover_hash()
  end

  def add_musicbrainz_data(record, musicbrainz_data) do
    record
    |> change(musicbrainz_data: musicbrainz_data)
  end

  def generate_cover_hash(record = %__MODULE__{cover_data: cover_data}) do
    hash = :crypto.hash(:sha256, cover_data) |> Base.encode16()

    record
    |> change()
    |> put_change(:cover_hash, hash)
  end

  def generate_cover_hash(changeset) do
    case get_change(changeset, :cover_data) do
      nil ->
        changeset

      cover_data ->
        hash = :crypto.hash(:sha256, cover_data) |> Base.encode16()
        put_change(changeset, :cover_hash, hash)
    end
  end

  def formats, do: @formats

  def format_short_label(:cd), do: "CD"
  def format_short_label(:vinyl), do: "V"
  def format_short_label(:blu_ray), do: "BR"
  def format_short_label(:dvd), do: "DVD"
  def format_short_label(:multi), do: "MLT"

  def format_long_label(:cd), do: "CD"
  def format_long_label(:vinyl), do: "Vinyl"
  def format_long_label(:blu_ray), do: "Blu-ray"
  def format_long_label(:dvd), do: "DVD"
  def format_long_label(:multi), do: "Multi"

  def type_short_label(:album), do: "ALB"
  def type_short_label(:ep), do: "EP"
  def type_short_label(:live), do: "LIVE"
  def type_short_label(:compilation), do: "CMP"
  def type_short_label(:single), do: "SNG"
  def type_short_label(:other), do: "OTH"

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
end
