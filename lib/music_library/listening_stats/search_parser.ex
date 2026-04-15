defmodule MusicLibrary.ListeningStats.SearchParser do
  @moduledoc """
  Parses structured search queries for scrobbled tracks into filter maps.

  Supports the following filters:

  - `record:value` — filter by record ID (matches all release IDs + artist/title fallback)
  - `album_mbid:value` — filter by album MusicBrainz ID (exact match)
  - `artist_mbid:value` — filter by artist MusicBrainz ID (exact match)
  - `artist:value` — filter by artist name
  - `album:value` — filter by album title
  - `track:value` — filter by track title

  Multi-word values can be quoted: `artist:"the pineapple thief"`.
  Bare words become free-text query terms searched across all fields.
  """

  @type search_result :: %{
          optional(:query) => String.t(),
          optional(:record) => String.t(),
          optional(:album_mbid) => String.t(),
          optional(:artist_mbid) => String.t(),
          optional(:artist) => String.t(),
          optional(:album) => String.t(),
          optional(:track) => String.t()
        }

  import NimbleParsec

  word = utf8_string([not: ?\s, not: ?,], min: 1)
  space = ignore(string(" "))
  comma = ignore(string(","))

  quoted_words =
    ignore(string(~s(")))
    |> utf8_string([not: ?\"], min: 1)
    |> ignore(string(~s(")))

  query = choice([quoted_words, word]) |> tag(:query)

  record_filter = ignore(string("record:"))
  record = concat(record_filter, query) |> tag(:record)

  album_mbid_filter = ignore(string("album_mbid:"))
  album_mbid = concat(album_mbid_filter, query) |> tag(:album_mbid)

  artist_mbid_filter = ignore(string("artist_mbid:"))
  artist_mbid = concat(artist_mbid_filter, query) |> tag(:artist_mbid)

  artist_filter = ignore(string("artist:"))
  artist = concat(artist_filter, query) |> tag(:artist)

  album_filter = ignore(string("album:"))
  album = concat(album_filter, query) |> tag(:album)

  track_filter = ignore(string("track:"))
  track = concat(track_filter, query) |> tag(:track)

  search =
    repeat(
      choice([
        record,
        album_mbid,
        artist_mbid,
        artist,
        album,
        track,
        space,
        comma,
        query
      ])
    )

  defparsecp(:search_parser, search)

  @doc """
  Parse a search query.

    iex> MusicLibrary.ListeningStats.SearchParser.parse("")
    {:ok, %{query: ""}}
    iex> MusicLibrary.ListeningStats.SearchParser.parse("hello, bye")
    {:ok, %{query: "hello bye"}}
    iex> MusicLibrary.ListeningStats.SearchParser.parse("marbles")
    {:ok, %{query: "marbles"}}
    iex> MusicLibrary.ListeningStats.SearchParser.parse("marillion marbles")
    {:ok, %{query: "marillion marbles"}}
    iex> MusicLibrary.ListeningStats.SearchParser.parse("artist:marillion album:marbles")
    {:ok, %{artist: "marillion", album: "marbles"}}
    iex> MusicLibrary.ListeningStats.SearchParser.parse("artist:marillion album:fugazi artist:fish")
    {:ok, %{artist: "marillion fish", album: "fugazi"}}
    iex> MusicLibrary.ListeningStats.SearchParser.parse(~s(artist:"the pineapple thief" wilderness))
    {:ok, %{artist: "the pineapple thief", query: "wilderness"}}
    iex> MusicLibrary.ListeningStats.SearchParser.parse("track:neverland")
    {:ok, %{track: "neverland"}}
    iex> MusicLibrary.ListeningStats.SearchParser.parse(~s(track:"the start of something beautiful"))
    {:ok, %{track: "the start of something beautiful"}}
    iex> MusicLibrary.ListeningStats.SearchParser.parse("album_mbid:abc-123")
    {:ok, %{album_mbid: "abc-123"}}
    iex> MusicLibrary.ListeningStats.SearchParser.parse("artist_mbid:def-456")
    {:ok, %{artist_mbid: "def-456"}}
    iex> MusicLibrary.ListeningStats.SearchParser.parse("record:abc-123-def")
    {:ok, %{record: "abc-123-def"}}
    iex> MusicLibrary.ListeningStats.SearchParser.parse("album_mbid:abc-123 artist:marillion")
    {:ok, %{album_mbid: "abc-123", artist: "marillion"}}
  """
  @spec parse(String.t()) :: {:ok, search_result()}
  def parse(""), do: {:ok, %{query: ""}}

  def parse(query) do
    {:ok, result, _rest, _context, _line, _byte_offset} = search_parser(query)

    {:ok, normalize(result)}
  end

  defp normalize(result) do
    Enum.reduce(result, %{}, fn
      {:record, [{:query, [value]}]}, acc ->
        Map.put(acc, :record, value)

      {:album_mbid, [{:query, [value]}]}, acc ->
        Map.put(acc, :album_mbid, value)

      {:artist_mbid, [{:query, [value]}]}, acc ->
        Map.put(acc, :artist_mbid, value)

      {:artist, [{:query, [value]}]}, acc ->
        Map.update(acc, :artist, value, &(&1 <> " " <> value))

      {:album, [{:query, [value]}]}, acc ->
        Map.update(acc, :album, value, &(&1 <> " " <> value))

      {:track, [{:query, [value]}]}, acc ->
        Map.update(acc, :track, value, &(&1 <> " " <> value))

      {:query, [value]}, acc ->
        Map.update(acc, :query, value, &(&1 <> " " <> value))

      _, acc when map_size(acc) == 0 ->
        %{query: ""}

      _, acc ->
        acc
    end)
  end
end
