defmodule Wikipedia.API do
  @moduledoc """
  Interface to the Wikidata and Wikipedia APIs.
  """

  alias Req.Request

  require Logger

  @spec get_wikipedia_title(String.t(), Wikipedia.Config.t()) ::
          {:ok, String.t() | nil} | {:error, term()}
  def get_wikipedia_title(wikidata_id, config) do
    case config
         |> new_request("https://www.wikidata.org")
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
         |> get_request() do
      {:ok, body} ->
        title = get_in(body, ["entities", wikidata_id, "sitelinks", "enwiki", "title"])
        {:ok, title}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec get_article_summary(String.t(), Wikipedia.Config.t()) :: {:ok, map()} | {:error, term()}
  def get_article_summary(title, config) do
    config
    |> new_request("https://en.wikipedia.org")
    |> Req.merge(url: "/api/rest_v1/page/summary/#{URI.encode(title)}")
    |> get_request()
  end

  @spec get_article_extract(String.t(), Wikipedia.Config.t()) ::
          {:ok, String.t() | nil} | {:error, term()}
  def get_article_extract(title, config) do
    case config
         |> new_request("https://en.wikipedia.org")
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
         |> get_request() do
      {:ok, body} ->
        extract =
          body
          |> get_in(["query", "pages"])
          |> Map.values()
          |> List.first()
          |> Map.get("extract")

        {:ok, extract}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp new_request(config, base_url) do
    Req.new(
      base_url: base_url,
      max_retries: 1,
      user_agent: config.user_agent
    )
    |> Request.merge_options(config.req_options)
    |> Req.RateLimiter.attach(name: :wikipedia, cooldown: config.api_cooldown)
    |> Request.append_request_steps(log_attempt: &log_attempt/1)
    |> Request.append_response_steps(log_error: &log_error/1)
  end

  defp get_request(request) do
    case Req.get(request) do
      {:ok, response} when response.status == 200 ->
        {:ok, response.body}

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
