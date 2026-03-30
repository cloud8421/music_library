defmodule MusicLibrary.Worker.PopulateGenresTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records
  alias MusicLibrary.Worker.PopulateGenres

  describe "perform/1" do
    test "populates genres and enqueues embedding generation" do
      record = record(%{genres: []})
      genres = ["progressive rock", "art rock", "symphonic rock"]

      Req.Test.stub(OpenAI.API, fn conn ->
        Req.Test.json(conn, %{
          "choices" => [
            %{"message" => %{"content" => JSON.encode!(%{"genres" => genres})}}
          ]
        })
      end)

      assert :ok = perform_job(PopulateGenres, %{"id" => record.id})

      updated = Records.get_record!(record.id)
      assert updated.genres == genres

      assert_enqueued(
        worker: MusicLibrary.Worker.GenerateRecordEmbedding,
        args: %{"record_id" => record.id}
      )
    end

    @tag :capture_log
    test "returns error when OpenAI API fails" do
      record = record(%{genres: []})

      Req.Test.stub(OpenAI.API, fn conn ->
        Plug.Conn.send_resp(conn, 500, JSON.encode!(%{"error" => "internal server error"}))
      end)

      assert {:error, _reason} = perform_job(PopulateGenres, %{"id" => record.id})
    end
  end
end
