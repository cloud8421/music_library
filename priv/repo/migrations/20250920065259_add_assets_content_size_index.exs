defmodule MusicLibrary.Repo.Migrations.AddAssetsContentSizeIndex do
  use Ecto.Migration

  def up do
    execute """
    CREATE index assets_content_size_index on assets(length(content));
    """
  end

  def down do
    execute """
    DROP index assets_content_size_index;
    """
  end
end
