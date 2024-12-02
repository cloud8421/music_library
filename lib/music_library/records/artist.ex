defmodule MusicLibrary.Records.Artist do
  use Ecto.Schema

  @primary_key {:musicbrainz_id, :binary_id, autogenerate: false}
  embedded_schema do
    field :name, :string
    field :sort_name, :string
    field :disambiguation, :string
  end
end
