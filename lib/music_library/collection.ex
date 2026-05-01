defmodule MusicLibrary.Collection do
  @moduledoc """
  Queries for collected records (where `purchased_at` is set).
  """

  import Ecto.Query, warn: false
  import MusicLibrary.Records.Query

  alias MusicLibrary.Records
  alias MusicLibrary.Records.{ArtistRecord, Record, SearchIndex}
  alias MusicLibrary.Repo

  @excluded_genres Application.compile_env!(:music_library, :excluded_genres)
  @pagination Application.compile_env!(:music_library, :pagination)

  @spec search_records(String.t(), MusicLibrary.Types.pagination_opts()) :: [SearchIndex.t()]
  def search_records(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, @pagination[:default_page_size])
    offset = Keyword.get(opts, :offset, 0)
    order = Keyword.get(opts, :order, :alphabetical)

    Records.search_records(base_search(), query, limit: limit, offset: offset, order: order)
  end

  @spec search_records_count(String.t()) :: non_neg_integer()
  def search_records_count(query) do
    Records.search_records_count(base_search(), query)
  end

  @spec count_records_by_format() :: [{String.t(), non_neg_integer()}]
  def count_records_by_format do
    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        group_by: r.format,
        order_by: [desc: count(r.id)],
        select: {r.format, count(r.id)}

    Repo.all(q)
  end

  @spec count_records_by_type() :: [{String.t(), non_neg_integer()}]
  def count_records_by_type do
    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        group_by: r.type,
        order_by: [desc: count(r.id)],
        select: {r.type, count(r.id)}

    Repo.all(q)
  end

  @spec get_records_on_this_day(Date.t()) :: [SearchIndex.t()]
  def get_records_on_this_day(date \\ Date.utc_today()) do
    month_day = Calendar.strftime(date, "%m-%d")

    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        where:
          fragment(
            "length(?) = 10 AND strftime('%m-%d', ?) = ?",
            r.release_date,
            r.release_date,
            ^month_day
          ),
        order_by: [{:desc, r.release_date}, order_alphabetically()],
        select: ^essential_fields()

    Repo.all(q)
  end

  @type grouped_record ::
          {:single, SearchIndex.t()}
          | {:group, %{representative: SearchIndex.t(), records: [SearchIndex.t()]}}

  @spec group_records_by_release_group([SearchIndex.t()]) :: [grouped_record()]
  def group_records_by_release_group(records) do
    records
    |> Enum.group_by(& &1.musicbrainz_id)
    |> Enum.map(fn
      {_mbid, [single]} ->
        {:single, single}

      {_mbid, [first | _] = group} ->
        sorted = Enum.sort_by(group, & &1.purchased_at, DateTime)
        {:group, %{representative: first, records: sorted}}
    end)
    |> Enum.sort_by(
      fn
        {:single, r} -> r.release_date
        {:group, %{representative: r}} -> r.release_date
      end,
      :desc
    )
  end

  @spec get_latest_record() :: SearchIndex.t() | nil
  def get_latest_record do
    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        order_by: [{:desc, r.purchased_at}, order_alphabetically()],
        limit: 1,
        select: ^essential_fields()

    Repo.one(q)
  end

  @spec get_latest_record!() :: SearchIndex.t()
  def get_latest_record! do
    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        order_by: [{:desc, r.purchased_at}, order_alphabetically()],
        limit: 1,
        select: ^essential_fields()

    Repo.one!(q)
  end

  @spec get_random_record!() :: SearchIndex.t()
  def get_random_record! do
    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        order_by: fragment("RANDOM()"),
        limit: 1,
        select: ^essential_fields()

    Repo.one!(q)
  end

  @spec count_records_by_artist(keyword()) :: [map()]
  def count_records_by_artist(opts \\ []) do
    limit = Keyword.get(opts, :limit, @pagination[:stats_limit])

    q =
      from r in fragment("records, json_each(records.artists)"),
        where: fragment("records.purchased_at IS NOT NULL"),
        group_by: fragment("? ->> '$.name'", r.value),
        order_by: [desc: fragment("count(1)")],
        select: %{
          id: fragment("? ->> '$.musicbrainz_id'", r.value),
          name: fragment("? ->> '$.name'", r.value),
          count: fragment("count(1)")
        },
        limit: ^limit

    Repo.all(q)
  end

  @spec count_records_by_genre(keyword()) :: [{String.t(), non_neg_integer()}]
  def count_records_by_genre(opts \\ []) do
    limit = Keyword.get(opts, :limit, @pagination[:stats_limit])

    q =
      from r in fragment("records, json_each(records.genres)"),
        where: fragment("records.purchased_at IS NOT NULL"),
        where: r.value not in @excluded_genres,
        group_by: r.value,
        order_by: [desc: fragment("count(1)")],
        select: {r.value, fragment("count(1)")},
        limit: ^limit

    Repo.all(q)
  end

  @spec count_records_by_release_year(keyword()) :: [{String.t(), non_neg_integer()}]
  def count_records_by_release_year(opts \\ []) do
    limit = Keyword.get(opts, :limit, @pagination[:stats_limit])

    q =
      from r in Record,
        where: not is_nil(r.purchased_at),
        where: not is_nil(r.release_date),
        where: r.release_date != "",
        group_by: fragment("substr(?, 1, 4)", r.release_date),
        order_by: [desc: fragment("count(1)")],
        select: {fragment("substr(?, 1, 4)", r.release_date), fragment("count(1)")},
        limit: ^limit

    Repo.all(q)
  end

  @spec collected_artist_ids() :: MapSet.t(String.t())
  def collected_artist_ids do
    from(ar in ArtistRecord,
      join: r in Record,
      on: r.id == ar.record_id,
      where: not is_nil(r.purchased_at),
      distinct: true,
      select: ar.musicbrainz_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  @max_genres_per_record 2
  @stats_limit 10

  @spec collection_summary() :: {String.t(), non_neg_integer()}
  def collection_summary do
    records =
      from(r in Record,
        where: not is_nil(r.purchased_at),
        order_by: [order_alphabetically()],
        select: ^essential_fields()
      )
      |> Repo.all()

    groups =
      records
      |> Enum.group_by(& &1.musicbrainz_id)
      |> Enum.map(fn {_id, group} -> format_group(group) end)
      |> Enum.sort()

    catalog = Enum.join(groups, "\n")
    stats = build_stats(records, length(groups))

    summary =
      cond do
        stats == "" and catalog == "" -> ""
        stats == "" -> catalog
        catalog == "" -> stats
        true -> stats <> "\n\n" <> catalog
      end

    {summary, length(groups)}
  end

  defp build_stats([], _group_count), do: ""

  defp build_stats(records, group_count) do
    genre_counts = compute_genre_counts(records)
    format_counts = compute_format_counts(records)
    decade_counts = compute_decade_counts(records)

    artist_count =
      records
      |> Enum.flat_map(& &1.artists)
      |> Enum.uniq_by(& &1.musicbrainz_id)
      |> length()

    [
      "# Stats: #{group_count} releases, #{artist_count} artists",
      genres_line(genre_counts),
      formats_line(format_counts),
      eras_line(decade_counts)
    ]
    |> Enum.join("\n")
  end

  defp compute_genre_counts(records) do
    records
    |> Enum.flat_map(&(&1.genres || []))
    |> Enum.reject(&(&1 in @excluded_genres))
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(@stats_limit)
  end

  defp compute_format_counts(records) do
    records
    |> Enum.map(& &1.format)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  defp compute_decade_counts(records) do
    records
    |> Enum.map(&extract_decade(&1.release_date))
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  defp genres_line([]), do: ""

  defp genres_line(counts) do
    items = Enum.map(counts, fn {genre, count} -> "#{genre} #{count}" end)
    "Genres: " <> Enum.join(items, ", ")
  end

  defp formats_line([]), do: ""

  defp formats_line(counts) do
    items = Enum.map(counts, fn {format, count} -> "#{format} #{count}" end)
    "Formats: " <> Enum.join(items, ", ")
  end

  defp eras_line([]), do: ""

  defp eras_line(counts) do
    items = Enum.map(counts, fn {decade, count} -> "#{decade} #{count}" end)
    "Eras: " <> Enum.join(items, ", ")
  end

  defp format_group(records) do
    record = hd(records)
    artist_names = Record.artist_names(record)
    formats = records |> Enum.map(& &1.format) |> Enum.uniq() |> Enum.join("/")
    year = extract_year(record.release_date)

    genres =
      records
      |> Enum.flat_map(&(&1.genres || []))
      |> Enum.uniq()
      |> Enum.take(@max_genres_per_record)

    base = "#{artist_names} - #{record.title} (#{year}, #{formats})"

    if genres == [] do
      base
    else
      base <> " [#{Enum.join(genres, ", ")}]"
    end
  end

  defp extract_year(nil), do: "Unknown"

  defp extract_year(date_str) when is_binary(date_str) do
    if String.length(date_str) >= 4 do
      String.slice(date_str, 0, 4)
    else
      date_str
    end
  end

  defp extract_decade(nil), do: nil

  defp extract_decade(date_str) when is_binary(date_str) do
    case Integer.parse(String.slice(date_str, 0, 4)) do
      {year, _} -> "#{div(year, 10) * 10}s"
      :error -> nil
    end
  end

  defp base_search do
    from r in SearchIndex,
      where: not is_nil(r.purchased_at)
  end
end
