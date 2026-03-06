defmodule LastFm.Album do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          musicbrainz_id: String.t(),
          title: String.t()
        }
  @primary_key false
  embedded_schema do
    field :musicbrainz_id, :string
    field :title, :string
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(album, attrs) do
    album
    |> cast(attrs, [:musicbrainz_id, :title])
    |> validate_required([:title])
  end
end
