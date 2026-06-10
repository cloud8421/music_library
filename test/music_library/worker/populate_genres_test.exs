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
        args: %{"record_id" => record.id},
        queue: :openai
      )
    end

    @tag :capture_log
    test "snoozes when OpenAI API returns a 5xx (transient)" do
      record = record(%{genres: []})

      Req.Test.stub(OpenAI.API, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "internal server error"}})
      end)

      assert {:snooze, 30} = perform_job(PopulateGenres, %{"id" => record.id})
    end

    @tag :capture_log
    test "cancels when OpenAI API returns 429 insufficient_quota (permanent)" do
      record = record(%{genres: []})

      Req.Test.stub(OpenAI.API, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          429,
          JSON.encode!(%{
            "error" => %{
              "code" => "insufficient_quota",
              "type" => "insufficient_quota",
              "message" => "quota exceeded"
            }
          })
        )
      end)

      assert {:cancel, %OpenAI.API.ErrorResponse{code: "insufficient_quota"}} =
               perform_job(PopulateGenres, %{"id" => record.id})
    end
  end
end
