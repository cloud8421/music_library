defmodule MusicLibrary.Records.ArtistRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "artists_records" do
    field :artist_id, :binary_id
    field :record_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(artist_record, attrs) do
    artist_record
    |> cast(attrs, [])
    |> validate_required([])
  end
end
