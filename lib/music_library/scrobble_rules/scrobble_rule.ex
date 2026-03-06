defmodule MusicLibrary.ScrobbleRules.ScrobbleRule do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          type: :album | :artist,
          match_value: String.t(),
          target_musicbrainz_id: String.t(),
          enabled: boolean(),
          description: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "scrobble_rules" do
    field :type, Ecto.Enum, values: [:album, :artist]
    field :match_value, :string
    field :target_musicbrainz_id, Ecto.UUID
    field :enabled, :boolean, default: true
    field :description, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(scrobble_rule, attrs) do
    scrobble_rule
    |> cast(attrs, [:type, :match_value, :target_musicbrainz_id, :enabled, :description])
    |> validate_required([:type, :match_value, :target_musicbrainz_id])
    |> validate_length(:match_value, min: 1, max: 500)
    |> validate_length(:description, max: 1000)
    |> unique_constraint([:type, :match_value], error_key: :match_value)
  end
end
