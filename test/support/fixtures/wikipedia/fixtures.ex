defmodule Wikipedia.Fixtures do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/wikipedia"])

  def wikidata_response do
    Path.join([@fixtures_folder, "wikidata_response.json"])
    |> File.read!()
    |> JSON.decode!()
  end

  def wikidata_response_no_enwiki do
    Path.join([@fixtures_folder, "wikidata_response_no_enwiki.json"])
    |> File.read!()
    |> JSON.decode!()
  end

  def article_summary do
    Path.join([@fixtures_folder, "article_summary.json"])
    |> File.read!()
    |> JSON.decode!()
  end

  def article_extract do
    Path.join([@fixtures_folder, "article_extract.json"])
    |> File.read!()
    |> JSON.decode!()
  end

  def article_extract_html do
    article_extract()
    |> get_in(["query", "pages"])
    |> Map.values()
    |> List.first()
    |> Map.get("extract")
  end
end
