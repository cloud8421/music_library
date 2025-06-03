defmodule MusicLibrary.Artists.Artist do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:musicbrainz_id, :binary_id, autogenerate: false}
  embedded_schema do
    field :name, :string
    field :sort_name, :string
    field :disambiguation, :string
    field :joinphrase, :string, default: " and "
  end

  def changeset(artist, attrs) do
    artist
    |> cast(attrs, [:name, :sort_name, :disambiguation, :joinphrase, :musicbrainz_id])
    |> validate_required([:name, :sort_name, :musicbrainz_id])
  end
end
