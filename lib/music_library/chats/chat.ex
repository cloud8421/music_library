defmodule MusicLibrary.Chats.Chat do
  use Ecto.Schema

  import Ecto.Changeset

  alias MusicLibrary.Chats.Message

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "chats" do
    field :entity, Ecto.Enum, values: [:record, :artist]
    field :musicbrainz_id, Ecto.UUID
    field :topic, :string

    field :message_count, :integer, virtual: true, default: 0

    has_many :messages, Message, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(chat, attrs) do
    chat
    |> cast(attrs, [:entity, :musicbrainz_id, :topic])
    |> validate_required([:entity, :musicbrainz_id])
    |> validate_length(:topic, max: 200)
  end
end
