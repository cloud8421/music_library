defmodule MusicLibrary.Repo.Migrations.CreateSecrets do
  use Ecto.Migration

  def change do
    create table(:secrets, primary_key: false) do
      add :name, :string, primary_key: true
      add :value, :binary, null: false

      timestamps()
    end
  end
end
