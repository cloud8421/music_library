defmodule MusicLibrary.Records.ArtistInfo do
  use Ecto.Schema
  import Ecto.Changeset

  alias MusicLibrary.Records.Cover

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "artist_infos" do
    field :musicbrainz_data, :map, default: %{}
    field :discogs_data, :map, default: %{}
    field :image_data, :binary
    field :image_data_hash, :string
    field :image_data_width, :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(artist_info, attrs) do
    artist_info
    |> cast(attrs, [
      :id,
      :musicbrainz_data,
      :discogs_data,
      :image_data,
      :image_data_width
    ])
    |> validate_required([:musicbrainz_data, :discogs_data])
    |> generate_image_hash()
  end

  def generate_image_hash(%__MODULE__{image_data: image_data} = artist_info) do
    change(artist_info, image_data_hash: Cover.hash(image_data))
  end

  def generate_image_hash(changeset) do
    case get_change(changeset, :image_data) do
      nil ->
        changeset

      image_data ->
        put_change(changeset, :image_data_hash, Cover.hash(image_data))
    end
  end
end
