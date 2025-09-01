defmodule MusicLibrary.Repo.Migrations.CreateAssets do
  use Ecto.Migration

  def change do
    create table(:assets, primary_key: false) do
      add :hash, :string, primary_key: true
      add :content, :binary, null: false
      add :format, :string, null: false
      add :properties, :map, default: %{}

      timestamps(type: :utc_datetime)
    end
  end
end
