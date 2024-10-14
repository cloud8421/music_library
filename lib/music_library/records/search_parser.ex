defmodule MusicLibrary.Records.SearchParser do
  @moduledoc """
  This module includes functions to parse a search string containing tagged entities,
  e.g. artists or albums.

  Implementation is most likely suboptimal, non-idiomatic and failing against specific
  edge cases I haven't thought about - not an expert in parsing.
  """

  import NimbleParsec

  word = utf8_string([not: ?\s], min: 1)
  space = ignore(string(" "))

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

  search = repeat(choice([artist, album, mbid, space, format, query]))

  defparsecp(:search_parser, search)

  @doc """
  Parse a search query.

    iex> MusicLibrary.Records.SearchParser.parse("")
    {:ok, %{query: ""}}
    iex> MusicLibrary.Records.SearchParser.parse("marbles")
    {:ok, %{query: "marbles"}}
    iex> MusicLibrary.Records.SearchParser.parse("artist:marillion album:marbles")
    {:ok, %{artist: "marillion", album: "marbles"}}
    iex> MusicLibrary.Records.SearchParser.parse("artist:marillion album:fugazi artist:fish")
    {:ok, %{artist: "marillion fish", album: "fugazi"}}
    iex> MusicLibrary.Records.SearchParser.parse(~s(artist:"the pineapple thief" wilderness))
    {:ok, %{artist: "the pineapple thief", query: "wilderness"}}
    iex> MusicLibrary.Records.SearchParser.parse(~s(artist:"the pineapple thief" format:cd))
    {:ok, %{artist: "the pineapple thief", format: :cd}}
    iex> MusicLibrary.Records.SearchParser.parse("format:vin")
    {:ok, %{query: ""}}
  """
  def parse(""), do: {:ok, %{query: ""}}

  def parse(query) do
    {:ok, result, _rest, _context, _line, _byte_offset} = search_parser(query)

    {:ok, normalize(result)}
  end

  def resolve_format(format) do
    Ecto.Enum.mappings(MusicLibrary.Records.Record, :format)
    |> Enum.find_value(fn {key, value} -> if value == format, do: key end)
  end

  defp normalize(result) do
    Enum.reduce(result, %{}, fn
      {:artist, [{:query, [value]}]}, acc ->
        Map.update(acc, :artist, value, &(&1 <> " " <> value))

      {:album, [{:query, [value]}]}, acc ->
        Map.update(acc, :album, value, &(&1 <> " " <> value))

      {:mbid, [{:query, [value]}]}, acc ->
        Map.put(acc, :mbid, value)

      {:format, [value]}, acc ->
        Map.put(acc, :format, value)

      {:query, [value]}, acc ->
        Map.update(acc, :query, value, &(&1 <> " " <> value))

      _, %{} ->
        %{query: ""}

      _, acc ->
        acc
    end)
  end
end
