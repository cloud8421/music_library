defmodule MusicLibrary.Repo.Migrations.StoreCoverImages do
  use Ecto.Migration

  def change do
    rename table(:records), :image, to: :image_url

    alter table(:records) do
      add :image_data, :blob
    end
  end
end
