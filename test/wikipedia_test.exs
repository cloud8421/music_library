defmodule WikipediaTest do
  use ExUnit.Case, async: true

  describe "get_artist_summary/1" do
    test "resolves wikidata ID to Wikipedia summary with full intro" do
      wikidata_id = "Q352766"
      summary = Wikipedia.Fixtures.article_summary()
      intro_html = Wikipedia.Fixtures.article_extract_html()

      Req.Test.stub(Wikipedia.API, fn conn ->
        case conn.request_path do
          "/w/api.php" ->
            case conn.params["action"] do
              "wbgetentities" ->
                Req.Test.json(conn, Wikipedia.Fixtures.wikidata_response())

              "query" ->
                Req.Test.json(conn, Wikipedia.Fixtures.article_extract())
            end

          "/api/rest_v1/page/summary/Steven%20Wilson" ->
            Req.Test.json(conn, summary)
        end
      end)

      assert {:ok, result} = Wikipedia.get_artist_summary(wikidata_id)
      assert result["extract"] == summary["extract"]
      assert result["description"] == summary["description"]
      assert result["intro_html"] == intro_html
    end

    test "returns error when no English Wikipedia article exists" do
      wikidata_id = "Q999999"

      Req.Test.stub(Wikipedia.API, fn conn ->
        Req.Test.json(conn, Wikipedia.Fixtures.wikidata_response_no_enwiki())
      end)

      assert {:error, :no_english_wikipedia} = Wikipedia.get_artist_summary(wikidata_id)
    end
  end
end
