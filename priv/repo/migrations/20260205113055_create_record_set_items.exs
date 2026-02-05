defmodule MusicLibrary.Repo.Migrations.CreateRecordSetItems do
  use Ecto.Migration

  def change do
    create table(:record_set_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :position, :integer, null: false

      add :record_set_id, references(:record_sets, type: :binary_id, on_delete: :delete_all),
        null: false

      add :record_id, references(:records, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:record_set_items, [:record_set_id])
    create unique_index(:record_set_items, [:record_set_id, :record_id])
    create index(:record_set_items, [:record_set_id, :position])
  end
end
