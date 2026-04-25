defmodule Wikipedia.API.ErrorResponse do
  @moduledoc """
  Structured error response for Wikipedia/Wikidata API calls.

  Wikipedia exposes two API surfaces with different error paradigms:

    * **Action API** (`/w/api.php`, used by `get_wikipedia_title/2` and
      `get_article_extract/2`) returns **HTTP 200 with an error in the body**:
      `%{"error" => %{"code" => ..., "info" => ...}}`. Without body inspection
      the error would be silently returned as `{:ok, body}`.

    * **REST v1 API** (`/api/rest_v1/page/summary/:title`, used by
      `get_article_summary/2`) uses classic HTTP status codes.

  `from_response/1` handles classic HTTP errors. `from_action_api_body/2` is a
  dedicated entry point for the HTTP 200 + body-error case.

  ## Non-error body shapes

  These are NOT errors and should continue to return `{:ok, body}`:

    * `%{"entities" => %{_id => %{"missing" => ""}}}` from `wbgetentities` —
      the facade converts this to `{:error, :no_english_wikipedia}` at a
      higher level.
    * `get_in(body, ["query", "pages", _, "extract"])` returning `nil` — a
      title exists but has no extract.

  The discriminator for an actual error is the literal top-level `"error"` key
  whose value is a map with both `"code"` and `"info"`.
  """

  @behaviour MusicLibrary.ErrorResponse

  alias MusicLibrary.HttpError
  alias MusicLibrary.RetryDelay

  @type t :: %__MODULE__{
          status: integer() | nil,
          code: String.t() | nil,
          message: String.t() | nil,
          kind: HttpError.kind(),
          body: term(),
          retry_delay_seconds: pos_integer() | nil
        }

  defstruct [:status, :code, :message, :kind, :body, :retry_delay_seconds]

  @spec from_response(Req.Response.t() | map()) :: t()
  def from_response(%{status: status, body: body} = response) do
    %__MODULE__{
      status: status,
      code: extract_rest_code(body),
      message: extract_rest_message(body),
      kind: HttpError.default_kind(status),
      body: body,
      retry_delay_seconds: RetryDelay.retry_after_seconds(response)
    }
  end

  @spec from_action_api_body(map(), Req.Response.t() | map()) :: t()
  def from_action_api_body(body, response \\ %{})

  def from_action_api_body(%{"error" => %{"code" => code, "info" => info}} = body, response) do
    %__MODULE__{
      status: 200,
      code: code,
      message: info,
      kind: action_api_kind(code),
      body: body,
      retry_delay_seconds: RetryDelay.retry_after_seconds(response)
    }
  end

  @impl MusicLibrary.ErrorResponse
  @spec retryable?(t()) :: boolean()
  def retryable?(%__MODULE__{kind: kind}) when kind in [:rate_limit, :server_error, :timeout],
    do: true

  def retryable?(%__MODULE__{}), do: false

  @impl MusicLibrary.ErrorResponse
  @spec retry_delay_seconds(t()) :: pos_integer()
  def retry_delay_seconds(%__MODULE__{retry_delay_seconds: seconds}) when is_integer(seconds),
    do: seconds

  def retry_delay_seconds(%__MODULE__{kind: :rate_limit}), do: 30
  def retry_delay_seconds(%__MODULE__{kind: :server_error}), do: 30
  def retry_delay_seconds(%__MODULE__{kind: :timeout}), do: 10
  def retry_delay_seconds(%__MODULE__{}), do: 30

  defp action_api_kind("ratelimited"), do: :rate_limit
  defp action_api_kind("maxlag"), do: :rate_limit
  defp action_api_kind("readonly"), do: :server_error
  defp action_api_kind("internal_api_error_" <> _), do: :server_error
  defp action_api_kind(_), do: :client_error

  defp extract_rest_code(%{"httpCode" => code}), do: to_string(code)
  defp extract_rest_code(_), do: nil

  defp extract_rest_message(%{"messageTranslations" => %{"en" => msg}}), do: msg
  defp extract_rest_message(%{"detail" => msg}) when is_binary(msg), do: msg
  defp extract_rest_message(_), do: nil
end
