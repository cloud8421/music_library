defmodule Wikipedia.API do
  @moduledoc """
  Interface to the Wikidata and Wikipedia APIs.
  """

  require Logger

  def get_wikipedia_title(wikidata_id, config) do
    request =
      Req.new(
        base_url: "https://www.wikidata.org",
        max_retries: 1,
        user_agent: config.user_agent
      )
      |> Req.Request.merge_options(config.req_options)
      |> Req.Request.append_request_steps(log_attempt: &log_attempt/1)
      |> Req.Request.append_response_steps(log_error: &log_error/1)
      |> Req.merge(
        url: "/w/api.php",
        params: [
          action: "wbgetentities",
          ids: wikidata_id,
          props: "sitelinks",
          sitefilter: "enwiki",
          format: "json"
        ]
      )

    case Req.get(request) do
      {:ok, response} when response.status == 200 ->
        title =
          get_in(response.body, ["entities", wikidata_id, "sitelinks", "enwiki", "title"])

        {:ok, title}

      {:ok, response} ->
        {:error, response.body}

      error ->
        error
    end
  end

  def get_article_summary(title, config) do
    request =
      Req.new(
        base_url: "https://en.wikipedia.org",
        max_retries: 1,
        user_agent: config.user_agent
      )
      |> Req.Request.merge_options(config.req_options)
      |> Req.Request.append_request_steps(log_attempt: &log_attempt/1)
      |> Req.Request.append_response_steps(log_error: &log_error/1)
      |> Req.merge(url: "/api/rest_v1/page/summary/#{URI.encode(title)}")

    case Req.get(request) do
      {:ok, response} when response.status == 200 ->
        {:ok, response.body}

      {:ok, response} ->
        {:error, response.body}

      error ->
        error
    end
  end

  def get_article_extract(title, config) do
    request =
      Req.new(
        base_url: "https://en.wikipedia.org",
        max_retries: 1,
        user_agent: config.user_agent
      )
      |> Req.Request.merge_options(config.req_options)
      |> Req.Request.append_request_steps(log_attempt: &log_attempt/1)
      |> Req.Request.append_response_steps(log_error: &log_error/1)
      |> Req.merge(
        url: "/w/api.php",
        params: [
          action: "query",
          titles: title,
          prop: "extracts",
          exintro: "1",
          format: "json"
        ]
      )

    case Req.get(request) do
      {:ok, response} when response.status == 200 ->
        extract =
          response.body
          |> get_in(["query", "pages"])
          |> Map.values()
          |> List.first()
          |> Map.get("extract")

        {:ok, extract}

      {:ok, response} ->
        {:error, response.body}

      error ->
        error
    end
  end

  defp log_attempt(request) do
    url = URI.to_string(request.url)
    Logger.debug("Fetching data from #{url}")
    request
  end

  defp log_error({request, response}) do
    if response.status in 400..499 or response.status in 500..599 do
      Logger.error(fn ->
        url = URI.to_string(request.url)
        "Failed to fetch data from #{url}, reason: #{inspect(response.body)}"
      end)
    end

    {request, response}
  end
end
