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
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "scrobble_rules" do
    field :type, Ecto.Enum, values: [:album, :artist]
    field :match_value, :string
    field :target_musicbrainz_id, Ecto.UUID
    field :enabled, :boolean, default: true
    field :description, :string

    timestamps()
  end

  @doc false
  def changeset(scrobble_rule, attrs) do
    scrobble_rule
    |> cast(attrs, [:type, :match_value, :target_musicbrainz_id, :enabled, :description])
    |> validate_required([:type, :match_value, :target_musicbrainz_id])
    |> unique_constraint([:type, :match_value], error_key: :match_value)
  end
end
