defmodule MusicLibrary.Records.Record do
  use Ecto.Schema
  import Ecto.Changeset

  alias MusicLibrary.{Records.Artist, Records.ArtistRecord}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "records" do
    field :type, Ecto.Enum, values: [:album, :ep, :live, :compilation, :single, :other]
    field :title, :string
    field :image, :string
    field :year, :integer
    field :musicbrainz_id, Ecto.UUID
    field :genres, {:array, :string}

    many_to_many :artists, Artist, join_through: ArtistRecord

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(record, attrs) do
    record
    |> cast(attrs, [:type, :title, :musicbrainz_id, :year, :genres, :image])
    |> validate_required([:type, :title, :musicbrainz_id, :year, :genres, :image])
  end
end
