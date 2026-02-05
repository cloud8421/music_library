defmodule MusicLibrary.Repo.Migrations.CreateRecordSets do
  use Ecto.Migration

  def change do
    create table(:record_sets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end
  end
end
