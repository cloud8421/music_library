defmodule MusicLibrary.Chats.Message do
  use Ecto.Schema

  import Ecto.Changeset

  alias MusicLibrary.Chats.Chat

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "chat_messages" do
    field :role, :string
    field :content, :string
    field :position, :integer

    belongs_to :chat, Chat

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content, :position])
    |> validate_required([:role, :content, :position])
    |> validate_inclusion(:role, ["user", "assistant"])
    |> validate_length(:content, max: 50_000)
  end
end
