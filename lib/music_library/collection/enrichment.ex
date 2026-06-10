defmodule MusicLibrary.Collection.Enrichment do
  @moduledoc """
  Batch-hydrates SearchIndex (and Record struct) results with additional data
  points: scrobble stats, artist country, and selected release info.

  All enrichment runs in fixed-count batch queries — 3 total, regardless of
  result size. No N+1 risk.
  """

  import Ecto.Query

  alias MusicBrainz.ReleaseSearchResult
  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibrary.Records.Record
  alias MusicLibrary.Repo

  @doc """
  Enriches a list of records with scrobble stats, artist country, and selected
  release information.

  Accepts any map or struct list where each element has:
    - `:id` (binary_id or string)
    - `:release_ids` (array of strings)
    - `:artists` (embedded list with `.musicbrainz_id`)
    - `:selected_release_id` (string or nil)

  Returns the same list with four additional fields on each element:
    - `:scrobble_count` (integer, always present, defaults to 0)
    - `:last_listened_at` (ISO8601 string or nil)
    - `:artist_country` (%{name: ..., code: ...} or nil)
    - `:selected_release` (map or nil)
  """
  @spec enrich([map()]) :: [map()]
  def enrich(records) do
    records
    |> enrich_scrobbles()
    |> enrich_artist_country()
    |> enrich_selected_release()
  end

  @doc """
  Adds `:scrobble_count` and `:last_listened_at` to each record.

  Uses a single batch query against `scrobbled_tracks`, matching either the
  album MusicBrainz ID against the record's `release_ids` or falling back to
  album title + main artist name when Last.fm does not provide album MBIDs.
  """
  @spec enrich_scrobbles([map()]) :: [map()]
  def enrich_scrobbles(records) do
    record_ids =
      records
      |> Enum.map(&Map.get(&1, :id))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if record_ids == [] do
      Enum.map(records, &put_empty_scrobble_stats/1)
    else
      lookup = build_scrobble_lookup(record_ids)

      Enum.map(records, fn record ->
        enrich_one_record_scrobbles(record, lookup)
      end)
    end
  end

  defp enrich_one_record_scrobbles(record, lookup) do
    stats = Map.get(lookup, Map.get(record, :id), %{scrobble_count: 0, last_listened_at: nil})

    record
    |> Map.put(:scrobble_count, stats.scrobble_count)
    |> Map.put(:last_listened_at, format_last_listened_at(stats.last_listened_at))
  end

  defp put_empty_scrobble_stats(record) do
    record
    |> Map.put(:scrobble_count, 0)
    |> Map.put(:last_listened_at, nil)
  end

  defp build_scrobble_lookup(record_ids) do
    from(r in Record,
      where: r.id in ^record_ids,
      select: %{
        record_id: r.id,
        scrobble_count:
          fragment(
            """
            (SELECT COUNT(DISTINCT t.scrobbled_at_uts)
            FROM scrobbled_tracks t
            WHERE json_extract(t.album, '$.musicbrainz_id') IN (SELECT value FROM json_each(?))
              OR (
                json_extract(t.album, '$.title') = ?
                AND json_extract(t.artist, '$.name') = json_extract(?, '$[0].name')
              ))
            """,
            r.release_ids,
            r.title,
            r.artists
          ),
        last_listened_at:
          fragment(
            """
            (SELECT MAX(t.scrobbled_at_uts)
            FROM scrobbled_tracks t
            WHERE json_extract(t.album, '$.musicbrainz_id') IN (SELECT value FROM json_each(?))
              OR (
                json_extract(t.album, '$.title') = ?
                AND json_extract(t.artist, '$.name') = json_extract(?, '$[0].name')
              ))
            """,
            r.release_ids,
            r.title,
            r.artists
          )
      }
    )
    |> Repo.all()
    |> Map.new(fn row ->
      {row.record_id,
       %{scrobble_count: row.scrobble_count, last_listened_at: row.last_listened_at}}
    end)
  end

  defp format_last_listened_at(nil), do: nil

  defp format_last_listened_at(uts) when is_integer(uts) do
    uts
    |> DateTime.from_unix!()
    |> DateTime.to_iso8601()
  end

  @doc """
  Adds `:artist_country` to each record, derived from the main artist.

  Extracts the first artist from the embedded `:artists` list, looks up
  `artist_infos` by the artist's MusicBrainz ID, and extracts the country
  via `ArtistInfo.country/1`.

  Returns `%{name: String, code: String}` or nil if no artist info exists.
  """
  @spec enrich_artist_country([map()]) :: [map()]
  def enrich_artist_country(records) do
    artist_ids =
      records
      |> Enum.map(&main_artist_mbid/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if artist_ids == [] do
      Enum.map(records, fn record ->
        Map.put(record, :artist_country, nil)
      end)
    else
      lookup = build_country_lookup(artist_ids)

      Enum.map(records, fn record ->
        mbid = main_artist_mbid(record)
        artist_country = if mbid, do: Map.get(lookup, mbid), else: nil
        Map.put(record, :artist_country, artist_country)
      end)
    end
  end

  defp main_artist_mbid(record) do
    artists = Map.get(record, :artists, [])

    case artists do
      [] ->
        nil

      [first | _] ->
        %{musicbrainz_id: mbid} = first
        mbid
    end
  end

  defp build_country_lookup(artist_ids) do
    from(ai in ArtistInfo,
      where: ai.id in ^artist_ids,
      select: %{id: ai.id, musicbrainz_data: ai.musicbrainz_data}
    )
    |> Repo.all()
    |> Map.new(fn row ->
      {row.id, ArtistInfo.country(%ArtistInfo{musicbrainz_data: row.musicbrainz_data})}
    end)
  end

  @doc """
  Adds `:selected_release` to each record with details about the selected
  release (edition).

  Looks up the `records` table by the record's `:id`, extracts the selected
  release with `Record.selected_release/1`, then exposes six fields: format,
  date, country, catalog_number, packaging, disambiguation.

  Returns a map or nil if no selected release is available.
  """
  @spec enrich_selected_release([map()]) :: [map()]
  def enrich_selected_release(records) do
    record_ids_with_selected =
      records
      |> Enum.filter(fn r ->
        sr_id = Map.get(r, :selected_release_id)
        sr_id != nil and sr_id != ""
      end)
      |> Enum.map(&Map.get(&1, :id))
      |> Enum.uniq()

    if record_ids_with_selected == [] do
      Enum.map(records, fn record ->
        Map.put(record, :selected_release, nil)
      end)
    else
      lookup = build_selected_release_lookup(record_ids_with_selected)

      Enum.map(records, fn record ->
        record
        |> Map.put(:selected_release, Map.get(lookup, Map.get(record, :id)))
      end)
    end
  end

  defp build_selected_release_lookup(record_ids) do
    from(r in Record,
      where: r.id in ^record_ids
    )
    |> Repo.all()
    |> Map.new(fn record ->
      {record.id, extract_selected_release(record)}
    end)
  end

  defp extract_selected_release(%Record{} = record) do
    case Record.selected_release(record) do
      nil ->
        nil

      release ->
        %{
          format: to_string(ReleaseSearchResult.format(release)),
          date: release.date,
          country: release.country,
          catalog_number: release.catalog_number,
          packaging: release.packaging,
          disambiguation: release.disambiguation
        }
    end
  end
end
