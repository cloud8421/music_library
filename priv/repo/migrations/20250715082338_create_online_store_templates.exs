defmodule MusicLibrary.Repo.Migrations.CreateOnlineStoreTemplates do
  use Ecto.Migration

  def change do
    create table(:online_store_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :url_template, :text, null: false
      add :enabled, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:online_store_templates, [:enabled])
  end
end
