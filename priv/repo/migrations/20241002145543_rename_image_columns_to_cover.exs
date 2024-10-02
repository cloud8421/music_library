defmodule MusicLibrary.Repo.Migrations.RenameImageColumnsToCover do
  use Ecto.Migration

  def up do
    rename table(:records), :image_url, to: :cover_url
    rename table(:records), :image_data, to: :cover_data
    rename table(:records), :image_data_hash, to: :cover_hash
  end

  def down do
    rename table(:records), :cover_url, to: :image_url
    rename table(:records), :cover_data, to: :image_data
    rename table(:records), :cover_hash, to: :image_data_hash
  end
end
