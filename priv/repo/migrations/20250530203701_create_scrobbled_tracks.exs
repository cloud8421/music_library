defmodule MusicLibrary.Repo.Migrations.CreateScrobbledTracks do
  use Ecto.Migration

  def change do
    create table(:scrobbled_tracks, primary_key: false) do
      add :scrobbled_at_uts, :integer, primary_key: true
      add :musicbrainz_id, :string
      add :title, :string
      add :cover_url, :string
      add :scrobbled_at_label, :string
      add :artist, :map
      add :album, :map
      add :last_fm_data, :map
    end
  end
end
