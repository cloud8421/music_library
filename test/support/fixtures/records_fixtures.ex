defmodule MusicLibrary.RecordsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MusicLibrary.Records` context.
  """

  alias MusicLibrary.Records.Record
  alias MusicLibrary.ReleaseGroupsFixtures

  @genres [
    "progressive rock",
    "art rock",
    "symphonic rock",
    "jazz fusion",
    "psychedelic rock",
    "space rock",
    "krautrock",
    "canterbury scene",
    "zeuhl",
    "avant-prog"
  ]
  @titles [
    "In the Court of the Crimson King",
    "Close to the Edge",
    "The Dark Side of the Moon",
    "Wish You Were Here",
    "Selling England by the Pound",
    "Larks Tongues in Aspic",
    "Red",
    "Foxtrot",
    "The Lamb Lies Down on Broadway",
    "Thick as a Brick",
    "Marbles",
    "Vigil in a Wilderness of Mirrors"
  ]
  @artists [
    "Steven Wilson",
    "King Crimson",
    "Pink Floyd",
    "Genesis",
    "Marillion",
    "Fish"
  ]
  # While it would be great to have this random, it's ok to use one single image
  @marbles_cover_data_path "#{__DIR__}/marillion-marbles.jpg"
  @raven_cover_data_path "#{__DIR__}/steven-wilson-raven.jpg"

  def marbles_cover_fixture, do: @marbles_cover_data_path
  def raven_cover_fixture, do: @raven_cover_data_path

  def record_fixture(attrs \\ %{}) do
    record_musicbrainz_id = Ecto.UUID.generate()
    artist_name = Enum.random(@artists)
    current_time = DateTime.utc_now()

    {:ok, record} =
      attrs
      |> Enum.into(%{
        genres: Enum.take_random(@genres, :rand.uniform(3)),
        cover_url: "https://coverartarchive.org/release-group/#{record_musicbrainz_id}/front",
        cover_data: File.read!(@marbles_cover_data_path),
        musicbrainz_id: record_musicbrainz_id,
        musicbrainz_data: ReleaseGroupsFixtures.release_group(),
        title: Enum.random(@titles),
        type: :album,
        format: Record.formats() |> Enum.random(),
        release: Enum.random(1969..2024) |> Integer.to_string(),
        purchased_at: current_time,
        artists: [artist_attrs(artist_name)]
      })
      |> MusicLibrary.Records.create_record()

    record
  end

  def record_fixture_with_artist(artist_name, record_attrs \\ %{}) do
    record_attrs
    |> Map.put(:artists, [artist_attrs(artist_name)])
    |> record_fixture()
  end

  defp artist_attrs(name) do
    %{
      name: name,
      musicbrainz_id: artist_uuid(name),
      sort_name: name,
      disambiguation: name
    }
  end

  # The following functions have been lifted from `Ecto.UUID`'s source.
  # The purpose is to provide a deterministic implementation of uuid generation
  # that can be used in tests to generate the same artist uuid.
  defp artist_uuid(name) do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.hash(:md5, name)
    encode(<<u0::48, 4::4, u1::12, 2::2, u2::62>>)
  end

  defp encode(
         <<a1::4, a2::4, a3::4, a4::4, a5::4, a6::4, a7::4, a8::4, b1::4, b2::4, b3::4, b4::4,
           c1::4, c2::4, c3::4, c4::4, d1::4, d2::4, d3::4, d4::4, e1::4, e2::4, e3::4, e4::4,
           e5::4, e6::4, e7::4, e8::4, e9::4, e10::4, e11::4, e12::4>>
       ) do
    <<e(a1), e(a2), e(a3), e(a4), e(a5), e(a6), e(a7), e(a8), ?-, e(b1), e(b2), e(b3), e(b4), ?-,
      e(c1), e(c2), e(c3), e(c4), ?-, e(d1), e(d2), e(d3), e(d4), ?-, e(e1), e(e2), e(e3), e(e4),
      e(e5), e(e6), e(e7), e(e8), e(e9), e(e10), e(e11), e(e12)>>
  end

  @compile {:inline, e: 1}

  defp e(0), do: ?0
  defp e(1), do: ?1
  defp e(2), do: ?2
  defp e(3), do: ?3
  defp e(4), do: ?4
  defp e(5), do: ?5
  defp e(6), do: ?6
  defp e(7), do: ?7
  defp e(8), do: ?8
  defp e(9), do: ?9
  defp e(10), do: ?a
  defp e(11), do: ?b
  defp e(12), do: ?c
  defp e(13), do: ?d
  defp e(14), do: ?e
  defp e(15), do: ?f
end
