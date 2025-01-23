defmodule MusicLibrary.Repo.Migrations.AddErrorTracker do
  use Ecto.Migration
  def up, do: ErrorTracker.Migration.up(version: 4)

  def down, do: ErrorTracker.Migration.down(version: 2)
end
