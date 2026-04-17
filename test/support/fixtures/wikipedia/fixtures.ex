defmodule Wikipedia.Fixtures do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/wikipedia"])

  # Cache fixtures at compile time to avoid repeated file I/O
  @external_resource Path.join([@fixtures_folder, "wikidata_response.json"])
  @wikidata_response Path.join([@fixtures_folder, "wikidata_response.json"])
                     |> File.read!()
                     |> JSON.decode!()

  @external_resource Path.join([@fixtures_folder, "wikidata_response_no_enwiki.json"])
  @wikidata_response_no_enwiki Path.join([@fixtures_folder, "wikidata_response_no_enwiki.json"])
                               |> File.read!()
                               |> JSON.decode!()

  @external_resource Path.join([@fixtures_folder, "article_summary.json"])
  @article_summary Path.join([@fixtures_folder, "article_summary.json"])
                   |> File.read!()
                   |> JSON.decode!()

  @external_resource Path.join([@fixtures_folder, "article_extract.json"])
  @article_extract Path.join([@fixtures_folder, "article_extract.json"])
                   |> File.read!()
                   |> JSON.decode!()

  def wikidata_response, do: @wikidata_response

  def wikidata_response_no_enwiki, do: @wikidata_response_no_enwiki

  def article_summary, do: @article_summary

  def article_extract, do: @article_extract

  def article_extract_html do
    @article_extract
    |> get_in(["query", "pages"])
    |> Map.values()
    |> List.first()
    |> Map.get("extract")
  end
end
