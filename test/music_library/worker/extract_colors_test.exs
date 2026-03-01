defmodule MusicLibrary.Worker.ExtractColorsTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records
  alias MusicLibrary.Worker.ExtractColors

  describe "perform/1" do
    @describetag :slow
    test "extracts colors using fast method" do
      record = record()

      assert :ok = perform_job(ExtractColors, %{"id" => record.id, "method" => "fast"})

      updated = Records.get_record!(record.id)
      assert is_list(updated.dominant_colors)
      assert updated.dominant_colors != []
      assert Enum.all?(updated.dominant_colors, &String.starts_with?(&1, "#"))
    end

    test "extracts colors using slow method" do
      record = record()

      assert :ok = perform_job(ExtractColors, %{"id" => record.id, "method" => "slow"})

      updated = Records.get_record!(record.id)
      assert is_list(updated.dominant_colors)
      assert updated.dominant_colors != []
    end

    test "raises when record does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        perform_job(ExtractColors, %{"id" => Ecto.UUID.generate(), "method" => "fast"})
      end
    end
  end
end
