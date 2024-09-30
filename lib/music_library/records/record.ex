defmodule MusicLibrary.Records.Record do
  use Ecto.Schema
  import Ecto.Changeset

  @formats [:cd, :vinyl, :blu_ray, :dvd, :multi]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "records" do
    field :type, Ecto.Enum, values: [:album, :ep, :live, :compilation, :single, :other]
    field :format, Ecto.Enum, values: @formats
    field :title, :string
    field :image_url, :string
    field :image_data, :binary
    field :image_data_hash, :string
    field :year, :integer
    field :musicbrainz_id, Ecto.UUID
    field :genres, {:array, :string}

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
      :year,
      :genres,
      :image_url,
      :image_data
    ])
    |> cast_embed(:artists, with: &artist_changeset/2)
    |> generate_image_data_hash()
    |> validate_required([:type, :title, :musicbrainz_id, :year, :genres])
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

  def add_image_data(record, image_data) do
    record
    |> change(image_data: image_data)
    |> generate_image_data_hash()
  end

  def generate_image_data_hash(record = %__MODULE__{image_data: image_data}) do
    hash = :crypto.hash(:sha256, image_data) |> Base.encode16()

    record
    |> change()
    |> put_change(:image_data_hash, hash)
  end

  def generate_image_data_hash(changeset) do
    case get_change(changeset, :image_data) do
      nil ->
        changeset

      image_data ->
        hash = :crypto.hash(:sha256, image_data) |> Base.encode16()
        put_change(changeset, :image_data_hash, hash)
    end
  end

  def formats, do: @formats

  def format_short_label(:cd), do: "CD"
  def format_short_label(:vinyl), do: "V"
  def format_short_label(:blu_ray), do: "BR"
  def format_short_label(:dvd), do: "DVD"
  def format_short_label(:multi), do: "MLT"
end
