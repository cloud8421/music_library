defmodule MusicLibrary.Collection.Enrichment do
  @moduledoc """
  Batch-hydrates SearchIndex (and Record struct) results with additional data
  points: scrobble stats, artist country, and selected release info.

  All enrichment runs in fixed-count batch queries — 3 total, regardless of
  result size. No N+1 risk and no title+artist fallback queries.
  """

  import Ecto.Query

  alias LastFm.Track
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

  Uses a single batch query against `scrobbled_tracks` keyed by
  `json_extract(album, '$.musicbrainz_id')` (the release MusicBrainz ID).
  For records with multiple release_ids (different editions of the same
  release group), scrobble counts are summed and the most recent
  `last_listened_at` across all releases is kept.
  """
  @spec enrich_scrobbles([map()]) :: [map()]
  def enrich_scrobbles(records) do
    release_ids =
      records
      |> Enum.flat_map(&Map.get(&1, :release_ids, []))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if release_ids == [] do
      Enum.map(records, fn record ->
        record
        |> Map.put(:scrobble_count, 0)
        |> Map.put(:last_listened_at, nil)
      end)
    else
      lookup = build_scrobble_lookup(release_ids)

      Enum.map(records, fn record ->
        enrich_one_record_scrobbles(record, lookup)
      end)
    end
  end

  defp enrich_one_record_scrobbles(record, lookup) do
    record_release_ids = Map.get(record, :release_ids, []) || []

    {total_count, latest_uts} =
      record_release_ids
      |> Enum.reduce({0, nil}, fn release_id, {count_acc, uts_acc} ->
        case Map.get(lookup, release_id) do
          nil ->
            {count_acc, uts_acc}

          %{scrobble_count: sc, last_listened_at: la} ->
            new_count = count_acc + sc
            new_uts = max_uts(uts_acc, la)
            {new_count, new_uts}
        end
      end)

    record
    |> Map.put(:scrobble_count, total_count)
    |> Map.put(:last_listened_at, format_last_listened_at(latest_uts))
  end

  defp build_scrobble_lookup(release_ids) do
    from(t in Track,
      where: fragment("json_extract(?, '$.musicbrainz_id')", t.album) in ^release_ids,
      group_by: fragment("json_extract(?, '$.musicbrainz_id')", t.album),
      select: %{
        release_id: fragment("json_extract(?, '$.musicbrainz_id')", t.album),
        scrobble_count: fragment("COUNT(DISTINCT ?)", t.scrobbled_at_uts),
        last_listened_at: max(t.scrobbled_at_uts)
      }
    )
    |> Repo.all()
    |> Map.new(fn row ->
      {row.release_id,
       %{scrobble_count: row.scrobble_count, last_listened_at: row.last_listened_at}}
    end)
  end

  defp max_uts(nil, nil), do: nil
  defp max_uts(nil, val), do: val
  defp max_uts(val, nil), do: val
  defp max_uts(a, b), do: max(a, b)

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
  release from `musicbrainz_data` using `Record.releases/1` and
  `Record.find_release/2`, then exposes six fields: format, date, country,
  catalog_number, packaging, disambiguation.

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
      where: r.id in ^record_ids,
      select: %{
        id: r.id,
        musicbrainz_data: r.musicbrainz_data,
        selected_release_id: r.selected_release_id
      }
    )
    |> Repo.all()
    |> Map.new(fn row ->
      selected_release =
        extract_selected_release(row.musicbrainz_data, row.selected_release_id)

      {row.id, selected_release}
    end)
  end

  defp extract_selected_release(nil, _), do: nil
  defp extract_selected_release(_, nil), do: nil
  defp extract_selected_release(_, ""), do: nil

  defp extract_selected_release(musicbrainz_data, selected_release_id) do
    # Build a minimal map with :musicbrainz_data for Record.releases/1 and Record.find_release/2
    temp_record = %{musicbrainz_data: musicbrainz_data}

    case Record.find_release(temp_record, selected_release_id) do
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
