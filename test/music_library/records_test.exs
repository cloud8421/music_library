defmodule MusicLibrary.RecordsTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Records
  alias MusicLibrary.Records.SearchIndex
  alias MusicBrainz.APIMock
  import MusicLibrary.Fixtures.Records
  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicBrainz.Fixtures.Release
  import Mox

  setup :verify_on_exit!

  defp create_records(_) do
    records = [
      record_with_artist("Marillion", %{title: "Brave", format: :vinyl}),
      record_with_artist("Marillion", %{title: "Brave (Live)", format: :cd, type: :live}),
      record_with_artist("Marillion", %{title: "Afraid of Sunlight"}),
      record_with_artist("Airbag", %{title: "The Greatest Show on Earth"}),
      record_with_artist("Airbag (AU)", %{title: "Libertad"})
    ]

    %{records: records}
  end

  # when searching we do not return all record fields (e.g. cover data)
  # so we rely on record ids to compare results
  defp search(query, limit, offset) do
    SearchIndex
    |> Records.search_records(query, limit: limit, offset: offset, order: :alphabetical)
    |> Enum.map(& &1.id)
  end

  describe "create_record/1" do
    test "populates computed values" do
      record =
        record(musicbrainz_data: release_group(:lockdown_trilogy))

      assert record.release_ids == ["77e746fc-566f-445b-a62b-cc014280fac9"]

      assert record.included_release_group_ids == [
               "749c07b5-4900-404b-bea9-bb6b16fa991e",
               "61077431-0057-4119-8f06-0df1098d21e5",
               "c36123e3-8899-48a5-8196-9dbb72421d69",
               "d463f2b1-d254-4baf-a957-fb78c6e5b956"
             ]

      assert record.cover_hash ==
               "599407DDF69907D4A60FE13CCAA824D25CF08DC124FD6AA3E8E7ECD98C885FFE"
    end
  end

  describe "refresh_musicbrainz_data/1" do
    test "updates release_ids and included_release_group_ids" do
      release_group_id = release_group_id(:marbles)

      record =
        record(
          musicbrainz_id: release_group_id,
          musicbrainz_data: Map.put(release_group(:marbles), "releases", [])
        )

      assert record.release_ids == []
      assert record.included_release_group_ids == []

      expect(APIMock, :get_release_group, fn ^release_group_id, _config ->
        {:ok, release_group(:lockdown_trilogy)}
      end)

      expect(APIMock, :get_releases, fn ^release_group_id, _opts, _config ->
        {:ok, %{"releases" => release_group(:lockdown_trilogy)["releases"]}}
      end)

      {:ok, updated_record} = Records.refresh_musicbrainz_data(record)

      assert record.release_ids !== updated_record.release_ids
      assert record.included_release_group_ids !== updated_record.included_release_group_ids
    end
  end

  describe "search_records/2" do
    setup [:create_records]

    test "untagged search (with limit and offset)", %{
      records: [brave_vinyl, brave_live_cd | _rest]
    } do
      assert [brave_vinyl.id, brave_live_cd.id] == search("brave", 10, 0)
      assert [brave_vinyl.id] == search("brave", 1, 0)
      assert [brave_live_cd.id] == search("brave", 1, 1)
    end

    test "tagged search - album", %{records: [_brave_vinyl, brave_live_cd | _rest]} do
      assert [brave_live_cd.id] == search(~s(album:"Brave \(Live\)"), 10, 0)
    end

    test "tagged search - artist", %{records: [_, _, _, greatest_show_on_earth, libertad]} do
      assert [greatest_show_on_earth.id, libertad.id] == search("artist:airbag", 10, 0)
      assert [libertad.id] == search(~s(artist:"airbag \(AU\)"), 10, 0)
    end

    test "tagged search - format", %{records: [_brave_vinyl, brave_live_cd | _rest]} do
      assert [brave_live_cd.id] == search("brave format:cd", 10, 0)
    end

    test "tagged search - type", %{records: [_brave_vinyl, brave_live_cd | _rest]} do
      assert [brave_live_cd.id] == search("brave type:live", 10, 0)
    end

    test "tagged search - mbid", %{records: [_, _, _, greatest_show_on_earth, libertad]} do
      [airbag_mbid] = Enum.map(greatest_show_on_earth.artists, fn a -> a.musicbrainz_id end)
      [airbag_au_mbid] = Enum.map(libertad.artists, fn a -> a.musicbrainz_id end)

      assert [greatest_show_on_earth.id] == search("mbid:#{airbag_mbid}", 10, 0)
      assert [libertad.id] == search("mbid:#{airbag_au_mbid}", 10, 0)
    end
  end

  describe "search_records_count/2" do
    setup [:create_records]

    test "untagged search" do
      assert 2 == Records.search_records_count(SearchIndex, "brave")
    end

    test "tagged search - album" do
      assert 1 == Records.search_records_count(SearchIndex, ~s(album:"Brave \(Live\)"))
    end

    test "tagged search - artist" do
      assert 2 == Records.search_records_count(SearchIndex, "artist:airbag")
      assert 1 == Records.search_records_count(SearchIndex, ~s(artist:"airbag \(AU\)"))
    end

    test "tagged search - format" do
      assert 1 == Records.search_records_count(SearchIndex, "brave format:cd")
    end

    test "tagged search - type" do
      assert 1 == Records.search_records_count(SearchIndex, "brave type:live")
    end

    test "tagged search - mbid", %{records: [_, _, _, greatest_show_on_earth, libertad]} do
      [airbag_mbid] = Enum.map(greatest_show_on_earth.artists, fn a -> a.musicbrainz_id end)
      [airbag_au_mbid] = Enum.map(libertad.artists, fn a -> a.musicbrainz_id end)

      assert 1 ==
               Records.search_records_count(SearchIndex, "mbid:#{airbag_mbid}")

      assert 1 == Records.search_records_count(SearchIndex, "mbid:#{airbag_au_mbid}")
    end
  end

  describe "get_record!/1" do
    test "it fetches the record by id" do
      # while this test may seem redundant, it implicitely checks that ALL record fields are returned,
      # as opposed to other code paths where we only return essential ones.
      expected = record()

      assert expected == Records.get_record!(expected.id)
    end
  end

  describe "get_artists_records/1" do
    test "it returns records with essential data" do
      expected = record()

      artist_musicbrainz_id = expected.artists |> hd() |> Map.get(:musicbrainz_id)

      [artist_record] = Records.get_artist_records(artist_musicbrainz_id)

      assert expected.id == artist_record.id
    end
  end

  describe "get_cover/1" do
    test "it returns the record cover by id" do
      # while this test may seem redundant, it implicitely checks that ALL record fields are returned,
      # as opposed to other code paths where we only return essential ones.
      expected = record()

      assert Map.take(expected, [:cover_hash, :cover_data]) == Records.get_cover(expected.id)
    end
  end

  describe "import_from_musicbrainz_release_group/2" do
    test "it saves a record with its cover art" do
      current_time = DateTime.utc_now()

      release_group = release_group(:marbles)
      release_group_id = release_group_id(:marbles)

      expect(APIMock, :get_release_group, fn ^release_group_id, _config ->
        {:ok, release_group}
      end)

      expect(APIMock, :get_releases, fn ^release_group_id, _opts, _config ->
        {:ok, %{"releases" => release_group["releases"]}}
      end)

      cover_data = File.read!(marbles_cover_fixture())

      expect(APIMock, :get_cover_art, fn {:musicbrainz_id, ^release_group_id}, _config ->
        {:ok, cover_data}
      end)

      assert {:ok, record} =
               Records.import_from_musicbrainz_release_group(release_group_id,
                 format: :vinyl,
                 purchased_at: current_time
               )

      assert [artist] = record.artists
      assert artist.name == "Marillion"

      assert record.musicbrainz_id == release_group_id
      assert record.title == "Marbles"
      assert record.format == :vinyl
      assert record.purchased_at == DateTime.truncate(current_time, :second)

      assert record.release_ids ==
               [
                 "0e290154-5375-4f4f-a658-4a92bf02faa5",
                 "3f1cc80f-4507-48a9-899c-c1bda83280c2",
                 "d3f9b9e2-73f5-4b47-a2a7-2c2199aad608",
                 "2c4ecd84-7a84-4f42-a600-2f00ed8978c9",
                 "ab151aa6-7538-4e93-be60-eded52b5b7b7",
                 "b94bbd1f-ae5d-4e7b-98ff-28bfe135f20c",
                 "4b9fe13b-4837-4c02-9368-e97ba6f5a086",
                 "3f89357a-eeb3-4040-af34-a27b7c2aea2b",
                 "a4b02377-0b5e-448e-9cd6-5500c0378523",
                 "f3937bc5-b99f-443a-9609-a404201f21ca"
               ]
    end
  end

  describe "import_from_musicbrainz_release/2" do
    test "it saves a record with its cover art" do
      current_time = DateTime.utc_now()

      release = release(:marbles)
      release_id = release_id(:marbles)

      release_group = release_group(:marbles)
      release_group_id = release_group_id(:marbles)

      expect(APIMock, :get_release, fn ^release_id, _config ->
        {:ok, release}
      end)

      expect(APIMock, :get_release_group, fn ^release_group_id, _config ->
        {:ok, release_group}
      end)

      expect(APIMock, :get_releases, fn ^release_group_id, _opts, _config ->
        {:ok, %{"releases" => release_group["releases"]}}
      end)

      cover_data = File.read!(marbles_cover_fixture())

      expect(APIMock, :get_cover_art, fn {:musicbrainz_id, ^release_group_id}, _config ->
        {:ok, cover_data}
      end)

      assert {:ok, record} =
               Records.import_from_musicbrainz_release(release_id,
                 format: :vinyl,
                 purchased_at: current_time
               )

      assert [artist] = record.artists
      assert artist.name == "Marillion"

      assert record.musicbrainz_id == release_group_id
      assert record.title == "Marbles"
      assert record.format == :vinyl
      assert record.purchased_at == DateTime.truncate(current_time, :second)

      assert record.release_ids ==
               [
                 "0e290154-5375-4f4f-a658-4a92bf02faa5",
                 "3f1cc80f-4507-48a9-899c-c1bda83280c2",
                 "d3f9b9e2-73f5-4b47-a2a7-2c2199aad608",
                 "2c4ecd84-7a84-4f42-a600-2f00ed8978c9",
                 "ab151aa6-7538-4e93-be60-eded52b5b7b7",
                 "b94bbd1f-ae5d-4e7b-98ff-28bfe135f20c",
                 "4b9fe13b-4837-4c02-9368-e97ba6f5a086",
                 "3f89357a-eeb3-4040-af34-a27b7c2aea2b",
                 "a4b02377-0b5e-448e-9cd6-5500c0378523",
                 "f3937bc5-b99f-443a-9609-a404201f21ca"
               ]
    end
  end

  describe "refresh cover/1" do
    test "it fetches and stores the updated cover" do
      record = record(cover_data: File.read!(marbles_cover_fixture()))

      raven_cover_data = File.read!(raven_cover_fixture())

      cover_url = record.cover_url

      expect(APIMock, :get_cover_art, fn {:url, ^cover_url}, _config ->
        {:ok, raven_cover_data}
      end)

      assert {:ok, updated_record} = Records.refresh_cover(record)

      assert updated_record.cover_data !== record.cover_data

      assert updated_record.cover_hash ==
               "14A033C9315419E0903B4D74EA6A95D4DC58CC7FE82F6F03BDA5750E7D3A590C"
    end
  end
end
