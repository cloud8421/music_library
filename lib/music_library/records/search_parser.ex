defmodule MusicLibrary.Records.SearchParser do
  @moduledoc """
  Parses structured search queries into filter maps.

  Supports the following filters:

  - `artist:value` — filter by artist name
  - `album:value` — filter by album name
  - `mbid:value` — filter by MusicBrainz ID
  - `genre:value` — filter by genre
  - `format:value` — filter by format (e.g. `cd`, `vinyl`)
  - `type:value` — filter by type (e.g. `album`, `single`)
  - `purchase_year:YYYY` — filter by purchase year

  Multi-word values can be quoted: `artist:"the pineapple thief"`.
  Unrecognized format/type values are silently ignored.
  Bare words become free-text query terms.
  """

  @type search_result :: %{
          optional(:query) => String.t(),
          optional(:artist) => String.t(),
          optional(:album) => String.t(),
          optional(:mbid) => String.t(),
          optional(:genre) => String.t(),
          optional(:format) => atom(),
          optional(:type) => atom(),
          optional(:purchase_year) => integer()
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

  artist_filter = ignore(string("artist:"))
  artist = concat(artist_filter, query) |> tag(:artist)

  album_filter = ignore(string("album:"))
  album = concat(album_filter, query) |> tag(:album)

  mbid_filter = ignore(string("mbid:"))
  mbid = concat(mbid_filter, query) |> tag(:mbid)

  year = integer(4) |> tag(:year)
  purchase_year_filter = ignore(string("purchase_year:"))
  purchase_year = concat(purchase_year_filter, year) |> tag(:purchase_year)

  genre_filter = ignore(string("genre:"))
  genre = concat(genre_filter, query) |> tag(:genre)

  format_filter = ignore(string("format:"))

  formats =
    Ecto.Enum.dump_values(MusicLibrary.Records.Record, :format)
    |> Enum.map(&string/1)
    |> choice()
    |> map({__MODULE__, :resolve_format, []})

  invalid_format = concat(format_filter, word)

  format =
    choice([concat(format_filter, formats), ignore(invalid_format)])
    |> tag(:format)

  type_filter = ignore(string("type:"))

  types =
    Ecto.Enum.dump_values(MusicLibrary.Records.Record, :type)
    |> Enum.map(&string/1)
    |> choice()
    |> map({__MODULE__, :resolve_type, []})

  invalid_type = concat(type_filter, word)

  type =
    choice([concat(type_filter, types), ignore(invalid_type)])
    |> tag(:type)

  search =
    repeat(choice([artist, album, mbid, genre, space, comma, format, type, purchase_year, query]))

  defparsecp(:search_parser, search)

  @doc """
  Parse a search query.

    iex> MusicLibrary.Records.SearchParser.parse("")
    {:ok, %{query: ""}}
    iex> MusicLibrary.Records.SearchParser.parse("hello, bye")
    {:ok, %{query: "hello bye"}}
    iex> MusicLibrary.Records.SearchParser.parse("marbles")
    {:ok, %{query: "marbles"}}
    iex> MusicLibrary.Records.SearchParser.parse("marillion marbles")
    {:ok, %{query: "marillion marbles"}}
    iex> MusicLibrary.Records.SearchParser.parse("artist:marillion album:marbles")
    {:ok, %{artist: "marillion", album: "marbles"}}
    iex> MusicLibrary.Records.SearchParser.parse("artist:marillion album:fugazi artist:fish")
    {:ok, %{artist: "marillion fish", album: "fugazi"}}
    iex> MusicLibrary.Records.SearchParser.parse(~s(artist:"the pineapple thief" wilderness))
    {:ok, %{artist: "the pineapple thief", query: "wilderness"}}
    iex> MusicLibrary.Records.SearchParser.parse(~s(artist:"the pineapple thief" format:cd))
    {:ok, %{artist: "the pineapple thief", format: :cd}}
    iex> MusicLibrary.Records.SearchParser.parse(~s(genre:"psychedelic rock"))
    {:ok, %{genre: "psychedelic rock"}}
    iex> MusicLibrary.Records.SearchParser.parse("format:vin")
    {:ok, %{query: ""}}
    iex> MusicLibrary.Records.SearchParser.parse("type:alb")
    {:ok, %{query: ""}}
    iex> MusicLibrary.Records.SearchParser.parse("artist:marillion format:vin")
    {:ok, %{artist: "marillion"}}
    iex> MusicLibrary.Records.SearchParser.parse("artist:marillion type:alb")
    {:ok, %{artist: "marillion"}}
    iex> MusicLibrary.Records.SearchParser.parse("type:album")
    {:ok, %{type: :album}}
    iex> MusicLibrary.Records.SearchParser.parse("purchase_year:2024")
    {:ok, %{purchase_year: 2024}}
  """
  @spec parse(String.t()) :: {:ok, search_result()}
  def parse(""), do: {:ok, %{query: ""}}

  def parse(query) do
    {:ok, result, _rest, _context, _line, _byte_offset} = search_parser(query)

    {:ok, normalize(result)}
  end

  @spec resolve_format(String.t()) :: atom() | nil
  def resolve_format(format) do
    Ecto.Enum.mappings(MusicLibrary.Records.Record, :format)
    |> Enum.find_value(fn {key, value} -> if value == format, do: key end)
  end

  @spec resolve_type(String.t()) :: atom() | nil
  def resolve_type(type) do
    Ecto.Enum.mappings(MusicLibrary.Records.Record, :type)
    |> Enum.find_value(fn {key, value} -> if value == type, do: key end)
  end

  defp normalize(result) do
    Enum.reduce(result, %{}, fn
      {:artist, [{:query, [value]}]}, acc ->
        Map.update(acc, :artist, value, &(&1 <> " " <> value))

      {:album, [{:query, [value]}]}, acc ->
        Map.update(acc, :album, value, &(&1 <> " " <> value))

      {:mbid, [{:query, [value]}]}, acc ->
        Map.put(acc, :mbid, value)

      {:genre, [{:query, [value]}]}, acc ->
        Map.put(acc, :genre, value)

      {:format, [value]}, acc ->
        Map.put(acc, :format, value)

      {:type, [value]}, acc ->
        Map.put(acc, :type, value)

      {:purchase_year, [{:year, [value]}]}, acc ->
        Map.put(acc, :purchase_year, value)

      {:query, [value]}, acc ->
        Map.update(acc, :query, value, &(&1 <> " " <> value))

      _, acc when map_size(acc) == 0 ->
        %{query: ""}

      _, acc ->
        acc
    end)
  end
end
