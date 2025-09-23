defmodule MusicLibrary.Notes.Note do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "notes" do
    field :entity, Ecto.Enum, values: [:record, :artist]
    field :content, :string, default: ""
    field :musicbrainz_id, Ecto.UUID

    timestamps(type: :utc_datetime)
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [
      :entity,
      :content,
      :musicbrainz_id
    ])
    |> validate_required([:entity, :musicbrainz_id])
  end
end
