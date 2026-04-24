defmodule Wikipedia.API do
  @moduledoc """
  Interface to the Wikidata and Wikipedia APIs.

  Two API surfaces are used, with different error handling:

    * **Action API** (`/w/api.php`) returns HTTP 200 with an `{"error": {...}}`
      payload on failure. `parse_error/1` promotes those bodies into
      `Wikipedia.API.ErrorResponse` errors.
    * **REST v1 API** (`/api/rest_v1/page/summary/:title`) uses classic HTTP
      status codes. `parse_error/1` handles non-2xx statuses the same way.
  """

  alias Req.Request
  alias Wikipedia.API.ErrorResponse

  require Logger

  @spec get_wikipedia_title(String.t(), Wikipedia.Config.t()) ::
          {:ok, String.t() | nil} | {:error, ErrorResponse.t() | Exception.t()}
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

  @spec get_article_summary(String.t(), Wikipedia.Config.t()) ::
          {:ok, map()} | {:error, ErrorResponse.t() | Exception.t()}
  def get_article_summary(title, config) do
    config
    |> new_request("https://en.wikipedia.org")
    |> Req.merge(url: "/api/rest_v1/page/summary/#{URI.encode(title)}")
    |> get_request()
  end

  @spec get_article_extract(String.t(), Wikipedia.Config.t()) ::
          {:ok, String.t() | nil} | {:error, ErrorResponse.t() | Exception.t()}
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
    |> Request.append_response_steps(parse_error: &parse_error/1)
  end

  defp get_request(request) do
    case Req.get(request) do
      {:ok, %{status: 200, body: %ErrorResponse{} = error}} ->
        {:error, error}

      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{body: %ErrorResponse{} = error}} ->
        {:error, error}

      {:ok, %{body: body}} ->
        {:error, body}

      error ->
        error
    end
  end

  defp log_attempt(request) do
    url = URI.to_string(request.url)
    Logger.debug("Fetching data from #{url}")
    request
  end

  # Action API: HTTP 200 with an error envelope in the body.
  defp parse_error(
         {request,
          %{status: 200, body: %{"error" => %{"code" => _, "info" => _}} = body} = response}
       ) do
    error = ErrorResponse.from_action_api_body(body)

    Logger.error(fn ->
      url = URI.to_string(request.url)
      "Failed to fetch data from #{url}, code: #{error.code}, info: #{error.message}"
    end)

    Request.halt(request, %{response | body: error})
  end

  # REST v1 API and other non-2xx responses.
  defp parse_error({request, %{status: status} = response}) when status not in 200..299 do
    error = ErrorResponse.from_response(response)

    Logger.error(fn ->
      url = URI.to_string(request.url)
      "Failed to fetch data from #{url}, status: #{status}, reason: #{inspect(response.body)}"
    end)

    Request.halt(request, %{response | body: error})
  end

  defp parse_error(tuple), do: tuple
end
