defmodule MusicLibrary.Records.RecordTest do
  use ExUnit.Case, async: true

  defp get_current_date(_) do
    %{current_date: ~D[2025-01-01]}
  end

  describe "released?/2" do
    setup :get_current_date

    test "returns true if the record has a release date in the past", %{
      current_date: current_date
    } do
      record = %MusicLibrary.Records.Record{release: "2024-01-01"}
      assert MusicLibrary.Records.Record.released?(record, current_date)
    end

    test "returns false if the record has a release date in the future", %{
      current_date: current_date
    } do
      record = %MusicLibrary.Records.Record{release: "2025-02-01"}
      refute MusicLibrary.Records.Record.released?(record, current_date)
    end

    test "returns true if the record is released today", %{current_date: current_date} do
      record = %MusicLibrary.Records.Record{release: "2025-01-01"}
      assert MusicLibrary.Records.Record.released?(record, current_date)
    end

    test "it returns true if the release date is not precise enough", %{
      current_date: current_date
    } do
      record = %MusicLibrary.Records.Record{release: "2019"}
      assert MusicLibrary.Records.Record.released?(record, current_date)
    end
  end
end
