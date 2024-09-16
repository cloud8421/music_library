defmodule MusicLibrary.RecordsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MusicLibrary.Records` context.
  """

  @doc """
  Generate a record.
  """
  def record_fixture(attrs \\ %{}) do
    {:ok, record} =
      attrs
      |> Enum.into(%{
        genres: ["option1", "option2"],
        image_url: "some image url",
        musicbrainz_id: "7488a646-e31f-11e4-aace-600308960662",
        title: "some title",
        type: :album,
        year: 42
      })
      |> MusicLibrary.Records.create_record()

    record
  end
end
