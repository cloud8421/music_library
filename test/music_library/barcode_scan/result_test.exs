defmodule MusicLibrary.BarcodeScan.ResultTest do
  use ExUnit.Case, async: true

  alias MusicBrainz.{ReleaseGroupSearchResult, ReleaseSearchResult}
  alias MusicLibrary.BarcodeScan.Result

  @release_group %ReleaseGroupSearchResult{
    id: "123",
    type: :album,
    title: "Test Release Group",
    artists: ["Test Artist"],
    release_date: "2021-01-01"
  }

  @release %ReleaseSearchResult{
    id: "123",
    title: "Test Release",
    release_group: @release_group,
    artists: ["Test Artist"],
    date: "2021-01-01",
    barcode: "1234567890",
    media: [
      %{
        format: "CD",
        track_count: 10,
        disc_count: 1
      }
    ]
  }

  describe "new/2" do
    test "creates a new result with status :new" do
      number = "123456789"
      result = Result.new(number, @release)

      assert result.status == :new
      assert result.number == number
      assert result.release == @release
      assert result.record_id == nil
    end
  end

  describe "wishlisted/3" do
    test "creates a result with status :wishlisted" do
      number = "123456789"
      record_id = "record-123"
      result = Result.wishlisted(number, record_id, @release)

      assert result.status == :wishlisted
      assert result.number == number
      assert result.record_id == record_id
      assert result.release == @release
    end
  end

  describe "collected/3" do
    test "creates a result with status :collected" do
      number = "123456789"
      record_id = "record-123"
      result = Result.collected(number, record_id, @release)

      assert result.status == :collected
      assert result.number == number
      assert result.record_id == record_id
      assert result.release == @release
    end
  end

  describe "not_found/1" do
    test "creates a result with status :not_found" do
      number = "123456789"
      result = Result.not_found(number)

      assert result.status == :not_found
      assert result.number == number
      assert result.release == nil
      assert result.record_id == nil
    end
  end
end
