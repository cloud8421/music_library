defmodule MusicLibrary.Worker.RefreshCoverTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Assets
  alias MusicLibrary.Records
  alias MusicLibrary.Worker.RefreshCover

  describe "perform/1" do
    test "refreshes the record cover from MusicBrainz" do
      record = record()

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Plug.Conn.send_resp(conn, 200, marbles_cover_data())
      end)

      assert :ok = perform_job(RefreshCover, %{"id" => record.id})

      updated = Records.get_record!(record.id)
      assert is_binary(updated.cover_hash) and byte_size(updated.cover_hash) > 0

      asset = Assets.get(updated.cover_hash)
      assert asset.format == "image/jpeg"
    end

    @tag :capture_log
    test "cancels the job when cover is not available" do
      record = record()

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      assert {:cancel, :cover_not_available} =
               perform_job(RefreshCover, %{"id" => record.id})
    end

    test "raises when record does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        perform_job(RefreshCover, %{"id" => Ecto.UUID.generate()})
      end
    end
  end
end
