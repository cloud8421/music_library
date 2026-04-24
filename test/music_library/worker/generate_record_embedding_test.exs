defmodule MusicLibrary.Worker.GenerateRecordEmbeddingTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records
  alias MusicLibrary.Records.Similarity
  alias MusicLibrary.Worker.GenerateRecordEmbedding

  describe "perform/1" do
    test "returns :ok and broadcasts update when embedding is generated" do
      record = record()

      Req.Test.stub(OpenAI.API, fn conn ->
        Req.Test.json(conn, %{"data" => [%{"embedding" => [0.1, 0.2, 0.3]}]})
      end)

      :ok = Records.subscribe(record.id)

      assert :ok = perform_job(GenerateRecordEmbedding, %{"record_id" => record.id})

      assert_receive {:update, %Records.Record{id: id}}
      assert id == record.id

      assert {:ok, text} = Similarity.get_embedding_text(record.id)
      assert text == Similarity.text_representation(record)
    end

    test "returns :ok without broadcasting when text representation is unchanged" do
      record = record()

      {:ok, _} =
        Similarity.store_embedding(
          record.id,
          SqliteVec.Float32.new([0.1, 0.2, 0.3]),
          Similarity.text_representation(record)
        )

      :ok = Records.subscribe(record.id)

      assert :ok = perform_job(GenerateRecordEmbedding, %{"record_id" => record.id})

      refute_receive {:update, _}
    end

    @tag :capture_log
    test "snoozes when OpenAI API fails with a 5xx (transient)" do
      record = record()

      Req.Test.stub(OpenAI.API, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "internal server error"}})
      end)

      assert {:snooze, 30} =
               perform_job(GenerateRecordEmbedding, %{"record_id" => record.id})
    end

    test "raises when record does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        perform_job(GenerateRecordEmbedding, %{"record_id" => Ecto.UUID.generate()})
      end
    end
  end
end
