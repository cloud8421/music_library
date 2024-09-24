defmodule MusicLibrary.RecordsTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Records

  describe "records" do
    alias MusicLibrary.Records.Record

    import MusicLibrary.RecordsFixtures

    @invalid_attrs %{
      type: nil,
      title: nil,
      image_url: nil,
      year: nil,
      musicbrainz_id: nil,
      genres: nil
    }

    test "list_records/0 returns all records" do
      record = record_fixture()
      assert Records.list_records() == [record]
    end

    test "get_record!/1 returns the record with given id" do
      record = record_fixture()
      assert Records.get_record!(record.id) == record
    end

    test "create_record/1 with valid data creates a record" do
      valid_attrs = %{
        type: :album,
        title: "some title",
        image_url: "some image url",
        year: 42,
        musicbrainz_id: "7488a646-e31f-11e4-aace-600308960662",
        genres: ["option1", "option2"],
        artists: [
          %{
            name: "some artist",
            sort_name: "some artist",
            disambiguation: "some artist",
            musicbrainz_id: "7488a646-e31f-11e4-aace-600308960663"
          }
        ]
      }

      assert {:ok, %Record{} = record} = Records.create_record(valid_attrs)
      assert record.type == :album
      assert record.title == "some title"
      assert record.image_url == "some image url"
      assert record.year == 42
      assert record.musicbrainz_id == "7488a646-e31f-11e4-aace-600308960662"
      assert record.genres == ["option1", "option2"]

      assert [
               %Record.Artist{
                 name: "some artist",
                 sort_name: "some artist",
                 disambiguation: "some artist",
                 musicbrainz_id: "7488a646-e31f-11e4-aace-600308960663"
               }
             ] = record.artists
    end

    test "create_record/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Records.create_record(@invalid_attrs)
    end

    test "update_record/2 with valid data updates the record" do
      record = record_fixture()

      update_attrs = %{
        type: :ep,
        title: "some updated title",
        image_url: "some updated image url",
        year: 43,
        musicbrainz_id: "7488a646-e31f-11e4-aace-600308960668",
        genres: ["option1"]
      }

      assert {:ok, %Record{} = record} = Records.update_record(record, update_attrs)
      assert record.type == :ep
      assert record.title == "some updated title"
      assert record.image_url == "some updated image url"
      assert record.year == 43
      assert record.musicbrainz_id == "7488a646-e31f-11e4-aace-600308960668"
      assert record.genres == ["option1"]
    end

    test "update_record/2 with invalid data returns error changeset" do
      record = record_fixture()
      assert {:error, %Ecto.Changeset{}} = Records.update_record(record, @invalid_attrs)
      assert record == Records.get_record!(record.id)
    end

    test "delete_record/1 deletes the record" do
      record = record_fixture()
      assert {:ok, %Record{}} = Records.delete_record(record)
      assert_raise Ecto.NoResultsError, fn -> Records.get_record!(record.id) end
    end

    test "change_record/1 returns a record changeset" do
      record = record_fixture()
      assert %Ecto.Changeset{} = Records.change_record(record)
    end
  end
end
