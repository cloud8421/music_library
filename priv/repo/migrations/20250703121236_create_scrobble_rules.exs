defmodule MusicLibrary.Repo.Migrations.CreateScrobbleRules do
  use Ecto.Migration

  def change do
    create table(:scrobble_rules) do
      add :type, :string, null: false
      add :match_value, :string, null: false
      add :target_musicbrainz_id, :string, null: false
      add :enabled, :boolean, default: true, null: false
      add :description, :text

      timestamps()
    end

    create index(:scrobble_rules, [:type, :match_value])
    create index(:scrobble_rules, [:enabled])
  end
end
