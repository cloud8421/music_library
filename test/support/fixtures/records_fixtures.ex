defmodule MusicLibrary.RecordsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MusicLibrary.Records` context.
  """

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
  @image_data_path "#{__DIR__}/marillion-marbles.jpg"

  def record_fixture(attrs \\ %{}) do
    musicbrainz_id = Ecto.UUID.generate()

    {:ok, record} =
      attrs
      |> Enum.into(%{
        genres: Enum.take_random(@genres, :rand.uniform(3)),
        image_url: "https://coverartarchive.org/release-group/#{musicbrainz_id}/front",
        image_data: File.read!(@image_data_path),
        musicbrainz_id: musicbrainz_id,
        title: Enum.random(@titles),
        type: :album,
        year: Enum.random(1969..2024)
      })
      |> MusicLibrary.Records.create_record()

    record
  end
end
