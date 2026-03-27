defmodule MusicLibrary.BarcodeScanTest do
  use MusicLibrary.DataCase

  import MusicBrainz.Fixtures.Release
  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.BarcodeScan
  alias MusicLibrary.BarcodeScan.Result
  alias MusicLibrary.Records
  alias MusicLibrary.Records.Record

  describe "scan/1" do
    test "returns :new when barcode matches a release not in the library" do
      releases = releases(:queen_greatest_hits)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, releases)
      end)

      assert {:ok, %Result{status: :new} = result} = BarcodeScan.scan("5052205070023")
      assert result.number == "5052205070023"
      assert result.release != nil
    end

    test "returns :wishlisted when barcode matches a wishlisted record" do
      releases = releases(:queen_greatest_hits)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, releases)
      end)

      # Get the first release ID and its format from the parsed results
      {:ok, [first_release | _]} = MusicBrainz.search_release_by_barcode("5052205070023")
      format = MusicBrainz.ReleaseSearchResult.format(first_release)

      # Create a wishlisted record with a matching release_id and format
      wishlisted_record =
        record(%{
          purchased_at: nil,
          format: format,
          musicbrainz_data: %{
            "releases" => [%{"id" => first_release.id}],
            "id" => Ecto.UUID.generate(),
            "title" => "Greatest Hits",
            "first-release-date" => "1981",
            "primary-type" => "Album",
            "secondary-types" => ["Compilation"],
            "genres" => [%{"name" => "rock"}],
            "artist-credit" => [
              %{"name" => "Queen", "artist" => %{"name" => "Queen", "sort-name" => "Queen"}}
            ]
          }
        })

      # Re-stub since the previous stub was consumed
      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, releases)
      end)

      assert {:ok, %Result{status: :wishlisted} = result} = BarcodeScan.scan("5052205070023")
      assert result.record_id == wishlisted_record.id
      assert result.release != nil
    end

    test "returns :collected when barcode matches a collected record" do
      releases = releases(:queen_greatest_hits)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, releases)
      end)

      {:ok, [first_release | _]} = MusicBrainz.search_release_by_barcode("5052205070023")
      format = MusicBrainz.ReleaseSearchResult.format(first_release)

      collected_record =
        record(%{
          purchased_at: DateTime.utc_now(),
          format: format,
          musicbrainz_data: %{
            "releases" => [%{"id" => first_release.id}],
            "id" => Ecto.UUID.generate(),
            "title" => "Greatest Hits",
            "first-release-date" => "1981",
            "primary-type" => "Album",
            "secondary-types" => ["Compilation"],
            "genres" => [%{"name" => "rock"}],
            "artist-credit" => [
              %{"name" => "Queen", "artist" => %{"name" => "Queen", "sort-name" => "Queen"}}
            ]
          }
        })

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, releases)
      end)

      assert {:ok, %Result{status: :collected} = result} = BarcodeScan.scan("5052205070023")
      assert result.record_id == collected_record.id
      assert result.release != nil
    end

    test "returns :not_found when barcode has no MusicBrainz results" do
      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, %{"releases" => []})
      end)

      assert {:ok, %Result{status: :not_found} = result} = BarcodeScan.scan("0000000000000")
      assert result.number == "0000000000000"
      assert result.release == nil
    end

    test "returns error when MusicBrainz API fails" do
      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, %Req.TransportError{reason: :timeout}} = BarcodeScan.scan("5052205070023")
    end
  end

  describe "import_results/2" do
    test "imports a new release and returns no errors" do
      current_time = DateTime.utc_now()

      release_data = release(:marbles)
      release_id = release_id(:marbles)

      release_group_data = release_group(:marbles)
      release_group_id = release_group_id(:marbles)
      release_group_releases_data = release_group_releases(:marbles)

      cover_data = marbles_cover_data()

      Req.Test.stub(MusicBrainz.API, fn conn ->
        case conn.path_info do
          [_ws, _version, "release-group", ^release_group_id] ->
            Req.Test.json(conn, release_group_data)

          [_ws, _version, "release", ^release_id] ->
            Req.Test.json(conn, release_data)

          [_ws, _version, "release"] ->
            Req.Test.json(conn, release_group_releases_data)

          [_release_group, ^release_group_id, "front"] ->
            Plug.Conn.send_resp(conn, 200, cover_data)
        end
      end)

      scan_result = %Result{
        status: :new,
        number: "1234567890",
        release: %MusicBrainz.ReleaseSearchResult{
          id: release_id,
          title: "Marbles",
          release_group: %{id: release_group_id, type: :album, title: "Marbles"},
          artists: "Marillion",
          date: "2004-05-03",
          barcode: "1234567890",
          media: [%{format: "CD", disc_count: 2, track_count: 13}]
        }
      }

      assert [] = BarcodeScan.import_results([scan_result], current_time)

      imported_record = Repo.get_by!(Record, musicbrainz_id: release_group_id)
      assert imported_record.title == "Marbles"
      assert imported_record.purchased_at == DateTime.truncate(current_time, :second)
    end

    test "updates a wishlisted record and returns no errors" do
      current_time = DateTime.utc_now()

      wishlisted_record = record(%{purchased_at: nil})

      scan_result = %Result{
        status: :wishlisted,
        number: "1234567890",
        record_id: wishlisted_record.id,
        release: %MusicBrainz.ReleaseSearchResult{
          id: "some-release-id",
          title: "Test",
          release_group: nil,
          artists: "Test Artist",
          date: "2021",
          barcode: "1234567890",
          media: [%{format: "CD", disc_count: 1, track_count: 10}]
        }
      }

      assert [] = BarcodeScan.import_results([scan_result], current_time)

      updated_record = Records.get_record!(wishlisted_record.id)
      assert updated_record.purchased_at == DateTime.truncate(current_time, :second)
    end

    test "returns error for already collected records" do
      scan_result = %Result{
        status: :collected,
        number: "1234567890",
        record_id: "some-record-id",
        release: %MusicBrainz.ReleaseSearchResult{
          id: "some-release-id",
          title: "Test",
          release_group: nil,
          artists: "Test Artist",
          date: "2021",
          barcode: "1234567890",
          media: [%{format: "CD", disc_count: 1, track_count: 10}]
        }
      }

      assert [{"1234567890", :already_collected}] =
               BarcodeScan.import_results([scan_result], DateTime.utc_now())
    end

    test "returns error for not found barcodes" do
      scan_result = %Result{
        status: :not_found,
        number: "0000000000000"
      }

      assert [{"0000000000000", :not_found}] =
               BarcodeScan.import_results([scan_result], DateTime.utc_now())
    end

    test "accumulates errors from multiple results" do
      collected_result = %Result{
        status: :collected,
        number: "1111111111",
        record_id: "some-id",
        release: %MusicBrainz.ReleaseSearchResult{
          id: "r1",
          title: "T",
          release_group: nil,
          artists: "A",
          date: "2021",
          barcode: "1111111111",
          media: [%{format: "CD", disc_count: 1, track_count: 1}]
        }
      }

      not_found_result = %Result{
        status: :not_found,
        number: "2222222222"
      }

      errors =
        BarcodeScan.import_results([collected_result, not_found_result], DateTime.utc_now())

      assert length(errors) == 2
      assert {"1111111111", :already_collected} in errors
      assert {"2222222222", :not_found} in errors
    end
  end
end
