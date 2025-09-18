defmodule MusicLibrary.Repo.Migrations.RemoveArtistInfoImageData do
  use Ecto.Migration

  def up do
    alter table(:artist_infos) do
      remove(:image_data)
      remove :image_data_width
    end
  end

  def down do
    alter table(:artist_infos) do
      add :image_data, :blob
      add :image_data_width, :integer
    end
  end
end
