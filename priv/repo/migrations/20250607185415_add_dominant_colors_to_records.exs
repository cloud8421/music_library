defmodule MusicLibrary.Repo.Migrations.AddDominantColorsToRecords do
  use Ecto.Migration

  def change do
    alter table(:records) do
      add :dominant_colors, {:array, :string}, default: []
    end
  end
end
