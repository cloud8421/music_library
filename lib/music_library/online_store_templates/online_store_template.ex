defmodule MusicLibrary.OnlineStoreTemplates.OnlineStoreTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "online_store_templates" do
    field :name, :string
    field :description, :string
    field :url_template, :string
    field :enabled, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :description, :url_template, :enabled])
    |> validate_required([:name, :url_template])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:url_template, min: 1, max: 500)
    |> validate_url_template()
  end

  defp validate_url_template(changeset) do
    if template = get_field(changeset, :url_template) do
      case URI.parse(template) do
        %URI{scheme: scheme} when scheme in ["http", "https"] -> changeset
        _ -> add_error(changeset, :url_template, "must be a valid HTTP or HTTPS URL")
      end
    else
      changeset
    end
  end
end
