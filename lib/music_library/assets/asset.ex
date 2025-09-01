defmodule MusicLibrary.Assets.Asset do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:hash, :string, autogenerate: false}
  schema "assets" do
    field :content, :binary
    field :format, :string
    field :properties, :map, default: %{}, read_after_writes: true

    timestamps(type: :utc_datetime)
  end

  def changeset(asset, attrs) do
    asset
    |> cast(attrs, [:content, :format, :properties])
    |> validate_required([:content, :format])
    |> generate_hash()
    |> unique_constraint(:hash)
  end

  defp generate_hash(changeset) do
    case get_change(changeset, :content) do
      nil ->
        changeset

      content ->
        put_change(changeset, :hash, hash(content))
    end
  end

  defp hash(content) do
    :crypto.hash(:sha256, content) |> Base.encode16()
  end
end
