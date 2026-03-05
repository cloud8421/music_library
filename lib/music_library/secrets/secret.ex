defmodule MusicLibrary.Secrets.Secret do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:name, :string, autogenerate: false}
  schema "secrets" do
    field :value, MusicLibrary.Encrypted.Binary

    timestamps(type: :utc_datetime)
  end

  def changeset(secret, attrs) do
    secret
    |> cast(attrs, [:name, :value])
    |> validate_required([:name, :value])
    |> validate_length(:name, min: 1, max: 100)
  end
end
