defmodule MusicLibrary.Records.Artist do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "artists" do
    field :name, :string
    field :image, :string
    field :musicbrainz_id, Ecto.UUID

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(artist, attrs) do
    artist
    |> cast(attrs, [:name, :musicbrainz_id, :image])
    |> validate_required([:name, :musicbrainz_id, :image])
  end
end
