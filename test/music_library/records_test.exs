defmodule MusicLibrary.RecordsTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Records
  alias MusicLibrary.Records.Record
  alias MusicBrainz.APIBehaviourMock
  import MusicLibrary.RecordsFixtures
  import MusicLibrary.ReleaseGroupsFixtures
  import Mox

  setup :verify_on_exit!

  defp create_records(_) do
    records = [
      record_fixture_with_artist("Marillion", %{title: "Brave", format: :vinyl}),
      record_fixture_with_artist("Marillion", %{title: "Brave (Live)", format: :cd, type: :live}),
      record_fixture_with_artist("Marillion", %{title: "Afraid of Sunlight"}),
      record_fixture_with_artist("Airbag", %{title: "The Greatest Show on Earth"}),
      record_fixture_with_artist("Airbag (AU)", %{title: "Libertad"})
    ]

    %{records: records}
  end

  # when searching we do not return all record fields (e.g. cover data)
  # so we rely on record ids to compare results
  defp search(query, limit, offset) do
    Record
    |> Records.search_records(query, limit: limit, offset: offset)
    |> Enum.map(& &1.id)
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
      assert 2 == Records.search_records_count(Record, "brave")
    end

    test "tagged search - album" do
      assert 1 == Records.search_records_count(Record, ~s(album:"Brave \(Live\)"))
    end

    test "tagged search - artist" do
      assert 2 == Records.search_records_count(Record, "artist:airbag")
      assert 1 == Records.search_records_count(Record, ~s(artist:"airbag \(AU\)"))
    end

    test "tagged search - format" do
      assert 1 == Records.search_records_count(Record, "brave format:cd")
    end

    test "tagged search - type" do
      assert 1 == Records.search_records_count(Record, "brave type:live")
    end

    test "tagged search - mbid", %{records: [_, _, _, greatest_show_on_earth, libertad]} do
      [airbag_mbid] = Enum.map(greatest_show_on_earth.artists, fn a -> a.musicbrainz_id end)
      [airbag_au_mbid] = Enum.map(libertad.artists, fn a -> a.musicbrainz_id end)

      assert 1 ==
               Records.search_records_count(Record, "mbid:#{airbag_mbid}")

      assert 1 == Records.search_records_count(Record, "mbid:#{airbag_au_mbid}")
    end
  end

  describe "get_record!/1" do
    test "it fetches the record by id" do
      # while this test may seem redundant, it implicitely checks that ALL record fields are returned,
      # as opposed to other code paths where we only return essential ones.
      expected = record_fixture()

      assert expected == Records.get_record!(expected.id)
    end
  end

  describe "get_cover/1" do
    test "it returns the record cover by id" do
      # while this test may seem redundant, it implicitely checks that ALL record fields are returned,
      # as opposed to other code paths where we only return essential ones.
      expected = record_fixture()

      assert Map.take(expected, [:cover_hash, :cover_data]) == Records.get_cover(expected.id)
    end
  end

  describe "search_release_group/2" do
    test "it returns results with correct limit and offset" do
      mock_results = release_group_search_results()

      expect(APIBehaviourMock, :search_release_group, fn "Marillion", limit: 20, offset: 10 ->
        {:ok, mock_results}
      end)

      assert {:ok, mock_results} ==
               Records.search_release_group("Marillion", limit: 20, offset: 10)
    end
  end

  describe "import_from_musicbrainz_release_group/2" do
    test "it saves a record with its cover art" do
      current_time = DateTime.utc_now()

      release_group = release_group()
      release_group_id = release_group_id()

      expect(APIBehaviourMock, :get_release_group, fn ^release_group_id ->
        {:ok, release_group}
      end)

      cover_data = File.read!(marbles_cover_fixture())

      expect(APIBehaviourMock, :get_cover_art, fn {:musicbrainz_id, ^release_group_id} ->
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
    end
  end
end
