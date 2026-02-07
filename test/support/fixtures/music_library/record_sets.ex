defmodule MusicLibrary.Fixtures.RecordSets do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MusicLibrary.RecordSets` context.
  """

  alias MusicLibrary.RecordSets

  def record_set(attrs \\ %{}) do
    {:ok, record_set} =
      attrs
      |> Enum.into(%{
        name: "Set #{System.unique_integer([:positive])}",
        description: "A test record set"
      })
      |> RecordSets.create_record_set()

    record_set
  end

  def record_set_with_records(n, attrs \\ %{}) do
    import MusicLibrary.Fixtures.Records, only: [record: 1]

    set = record_set(attrs)

    records =
      Enum.map(1..n, fn _ ->
        rec = record(%{})
        {:ok, _} = RecordSets.add_record_to_set(set, rec.id)
        rec
      end)

    {RecordSets.get_record_set!(set.id), records}
  end
end
