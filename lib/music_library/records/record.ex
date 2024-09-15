defmodule MusicLibrary.Records.Record do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "records" do
    field :type, Ecto.Enum, values: [:album, :ep, :live, :compilation, :single, :other]
    field :title, :string
    field :image, :string
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
    |> cast(attrs, [:type, :title, :musicbrainz_id, :year, :genres, :image])
    |> validate_required([:type, :title, :musicbrainz_id, :year, :genres, :image])
  end

  def add_artists(record, artists_attrs) do
    record
    |> change()
    |> put_embed(:artists, artists_attrs)
  end
end
