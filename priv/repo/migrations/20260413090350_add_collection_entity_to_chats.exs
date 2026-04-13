defmodule MusicLibrary.Repo.Migrations.AddCollectionEntityToChats do
  use Ecto.Migration

  # The entity column is a plain string in SQLite — no CHECK constraint to alter.
  # This migration documents the addition of the :collection entity type.
  def change do
  end
end
