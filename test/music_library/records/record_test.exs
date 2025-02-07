defmodule MusicLibrary.Records.RecordTest do
  use ExUnit.Case, async: true

  import MusicLibrary.ReleaseGroupsFixtures
  alias MusicLibrary.Records.Record

  defp get_current_date(_) do
    %{current_date: ~D[2025-01-01]}
  end

  describe "released?/2" do
    setup :get_current_date

    test "returns true if the record has a release date in the past", %{
      current_date: current_date
    } do
      record = %Record{release: "2024-01-01"}
      assert Record.released?(record, current_date)
    end

    test "returns false if the record has a release date in the future", %{
      current_date: current_date
    } do
      record = %Record{release: "2025-02-01"}
      refute Record.released?(record, current_date)
    end

    test "returns true if the record is released today", %{current_date: current_date} do
      record = %Record{release: "2025-01-01"}
      assert Record.released?(record, current_date)
    end

    test "it returns true if the release date is not precise enough", %{
      current_date: current_date
    } do
      record = %Record{release: "2019"}
      assert Record.released?(record, current_date)
    end
  end

  describe "child_release_groups/1" do
    test "returns the release groups of children releases" do
      release_group = release_group(:lockdown_trilogy)

      record =
        %Record{musicbrainz_data: release_group}
        |> Record.update_included_release_group_ids()
        |> Ecto.Changeset.apply_changes()

      assert Record.child_release_groups(record) == [
               %MusicBrainz.ReleaseGroup{
                 id: "749c07b5-4900-404b-bea9-bb6b16fa991e",
                 type: :other,
                 title: "Claustrophobic Universe",
                 release: "2021-04-23",
                 artists: "Mariusz Duda"
               },
               %MusicBrainz.ReleaseGroup{
                 id: "61077431-0057-4119-8f06-0df1098d21e5",
                 type: :other,
                 title: "Interior Drawings",
                 release: "2021-12-10",
                 artists: "Mariusz Duda"
               },
               %MusicBrainz.ReleaseGroup{
                 id: "c36123e3-8899-48a5-8196-9dbb72421d69",
                 type: :other,
                 title: "Let’s Meet Outside",
                 release: "2022-05-20",
                 artists: "Mariusz Duda"
               },
               %MusicBrainz.ReleaseGroup{
                 id: "d463f2b1-d254-4baf-a957-fb78c6e5b956",
                 type: :other,
                 title: "Lockdown Spaces",
                 release: "2020-06-26",
                 artists: "Mariusz Duda"
               }
             ]
    end
  end

  describe "child_release_groups_count/1" do
    test "returns the release groups count of children releases" do
      release_group = release_group(:lockdown_trilogy)

      record =
        %Record{musicbrainz_data: release_group}
        |> Record.update_included_release_group_ids()
        |> Ecto.Changeset.apply_changes()

      assert Record.child_release_groups_count(record) == 4
    end
  end

  describe "add_musicbrainz_data/2" do
    test "it updates release_ids and included_release_group_ids" do
      record = %Record{}
      assert record.release_ids == []
      assert record.included_release_group_ids == []

      updated_record =
        record
        |> Record.add_musicbrainz_data(release_group(:lockdown_trilogy))
        |> Ecto.Changeset.apply_changes()

      assert updated_record.release_ids == ["77e746fc-566f-445b-a62b-cc014280fac9"]

      assert updated_record.included_release_group_ids == [
               "749c07b5-4900-404b-bea9-bb6b16fa991e",
               "61077431-0057-4119-8f06-0df1098d21e5",
               "c36123e3-8899-48a5-8196-9dbb72421d69",
               "d463f2b1-d254-4baf-a957-fb78c6e5b956"
             ]
    end
  end
end
