defmodule MusicLibrary.Repo.Migrations.AddImageDataHashToRecords do
  use Ecto.Migration

  def change do
    alter table(:records) do
      add :image_data_hash, :string
    end
  end
end
