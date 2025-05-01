defmodule MusicLibrary.Repo.Migrations.RenameRecordsReleaseToReleaseDate do
  use Ecto.Migration

  def up do
    rename table(:records), :release, to: :release_date

    flush()

    execute "DROP TRIGGER IF EXISTS records_after_update"
    execute "DROP TRIGGER IF EXISTS records_after_insert"
    execute "DROP TABLE records_search_index"

    flush()

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
      release_date
    );
    """

    flush()

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
        release_date
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
        release_date
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
        release_date
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
        release_date
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
      release_date
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
      release_date
    FROM records;
    """
  end

  def down do
    rename table(:records), :release_date, to: :release

    flush()

    execute "DROP TRIGGER IF EXISTS records_after_update"
    execute "DROP TRIGGER IF EXISTS records_after_insert"
    execute "DROP TABLE records_search_index"

    flush()

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
  end
end
