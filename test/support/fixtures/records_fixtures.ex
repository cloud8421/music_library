defmodule MusicLibrary.RecordsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MusicLibrary.Records` context.
  """

  alias MusicLibrary.Records.Record

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
    "Larks' Tongues in Aspic",
    "Red",
    "Foxtrot",
    "The Lamb Lies Down on Broadway",
    "Thick as a Brick"
  ]
  # While it would be great to have this random, it's ok to use one single image
  @marbles_cover_data_path "#{__DIR__}/marillion-marbles.jpg"
  @raven_cover_data_path "#{__DIR__}/steven-wilson-raven.jpg"

  def marbles_cover_fixture, do: @marbles_cover_data_path
  def raven_cover_fixture, do: @raven_cover_data_path

  def record_fixture(attrs \\ %{}) do
    musicbrainz_id = Ecto.UUID.generate()

    {:ok, record} =
      attrs
      |> Enum.into(%{
        genres: Enum.take_random(@genres, :rand.uniform(3)),
        cover_url: "https://coverartarchive.org/release-group/#{musicbrainz_id}/front",
        cover_data: File.read!(@marbles_cover_data_path),
        musicbrainz_id: musicbrainz_id,
        title: Enum.random(@titles),
        type: :album,
        format: Record.formats() |> Enum.random(),
        release: Enum.random(1969..2024) |> Integer.to_string()
      })
      |> MusicLibrary.Records.create_record()

    record
  end
end
