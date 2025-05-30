defmodule LastFm.Album do
  use Ecto.Schema

  @type t :: %__MODULE__{
          musicbrainz_id: String.t(),
          title: String.t()
        }
  embedded_schema do
    field :musicbrainz_id, :string
    field :title, :string
  end
end
