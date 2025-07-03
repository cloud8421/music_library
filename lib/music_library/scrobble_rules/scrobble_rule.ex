defmodule MusicLibrary.ScrobbleRules.ScrobbleRule do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          type: String.t(),
          match_value: String.t(),
          target_musicbrainz_id: String.t(),
          enabled: boolean(),
          description: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @valid_types ~w(album artist)

  schema "scrobble_rules" do
    field :type, :string
    field :match_value, :string
    field :target_musicbrainz_id, :string
    field :enabled, :boolean, default: true
    field :description, :string

    timestamps()
  end

  @doc false
  def changeset(scrobble_rule, attrs) do
    scrobble_rule
    |> cast(attrs, [:type, :match_value, :target_musicbrainz_id, :enabled, :description])
    |> validate_required([:type, :match_value, :target_musicbrainz_id])
    |> validate_inclusion(:type, @valid_types)
    |> validate_musicbrainz_id_format(:target_musicbrainz_id)
  end

  defp validate_musicbrainz_id_format(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      case value do
        "" ->
          [{field, "cannot be empty"}]

        value when is_binary(value) ->
          if String.match?(
               value,
               ~r/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i
             ) do
            []
          else
            [{field, "must be a valid MusicBrainz ID (UUID format)"}]
          end

        _ ->
          [{field, "must be a string"}]
      end
    end)
  end
end
