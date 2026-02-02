defmodule MusicLibrary.Repo.Migrations.AddScrobbleRulesConstraints do
  use Ecto.Migration

  def change do
    drop index(:scrobble_rules, [:type, :match_value])
    create unique_index(:scrobble_rules, [:type, :match_value], unique: true)
  end
end
