defmodule MusicLibrary.Repo.Migrations.CreateRecordsSearchIndex do
  use Ecto.Migration

  def up do
    execute """
    CREATE VIRTUAL TABLE records_search_index USING fts5(
      id UNINDEXED,
      type,
      format,
      title,
      artists,
      genres,
      musicbrainz_id,
      release_ids UNINDEXED,
      included_release_group_ids UNINDEXED,
      cover_hash UNINDEXED,
      purchased_at UNINDEXED,
      release
    );
    """

    flush()

    execute """
    CREATE TRIGGER records_search_index_before_update
    BEFORE UPDATE ON records
    BEGIN
      DELETE FROM records_search_index WHERE id=OLD.id;
    END;
    """

    execute """
    CREATE TRIGGER records_search_index_before_delete
    BEFORE DELETE ON records
    BEGIN
      DELETE FROM records_search_index WHERE id=OLD.id;
    END;
    """

    execute """
    CREATE TRIGGER records_after_insert
    AFTER INSERT ON records
    BEGIN
      INSERT INTO records_search_index(
        id,
        type,
        format,
        title,
        artists,
        genres,
        musicbrainz_id,
        release_ids,
        included_release_group_ids,
        cover_hash,
        purchased_at,
        release
      ) SELECT
        id,
        type,
        format,
        title,
        artists,
        genres,
        musicbrainz_id,
        release_ids,
        included_release_group_ids,
        cover_hash,
        purchased_at,
        release
      FROM records
      WHERE NEW.id = records.id;
    END;
    """

    execute """
    CREATE TRIGGER records_after_update
    AFTER UPDATE ON records
    BEGIN
      INSERT INTO records_search_index(
        id,
        type,
        format,
        title,
        artists,
        genres,
        musicbrainz_id,
        release_ids,
        included_release_group_ids,
        cover_hash,
        purchased_at,
        release
      ) SELECT
        id,
        type,
        format,
        title,
        artists,
        genres,
        musicbrainz_id,
        release_ids,
        included_release_group_ids,
        cover_hash,
        purchased_at,
        release
      FROM records
      WHERE NEW.id = records.id;
    END;
    """

    flush()

    execute """
    INSERT INTO records_search_index(
      id,
      type,
      format,
      title,
      artists,
      genres,
      musicbrainz_id,
      release_ids,
      included_release_group_ids,
      cover_hash,
      purchased_at,
      release
    ) SELECT
      id,
      type,
      format,
      title,
      artists,
      genres,
      musicbrainz_id,
      release_ids,
      included_release_group_ids,
      cover_hash,
      purchased_at,
      release
    FROM records;
    """

    flush()
  end

  def down do
    execute "DROP TRIGGER IF EXISTS records_search_index_before_update"
    execute "DROP TRIGGER IF EXISTS records_search_index_before_delete"
    execute "DROP TRIGGER IF EXISTS records_after_update"
    execute "DROP TABLE records_search_index"
  end
end
