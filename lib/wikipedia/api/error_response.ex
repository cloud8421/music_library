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

  `from_response/1` handles both paths. `from_action_api_body/1` is a dedicated
  entry point for the HTTP 200 + body-error case.

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

  @type t :: %__MODULE__{
          status: integer() | nil,
          code: String.t() | nil,
          message: String.t() | nil,
          kind: HttpError.kind(),
          body: term()
        }

  defstruct [:status, :code, :message, :kind, :body]

  @spec from_response(Req.Response.t() | map()) :: t()
  def from_response(%{status: status, body: body} = _response) do
    %__MODULE__{
      status: status,
      code: extract_rest_code(body),
      message: extract_rest_message(body),
      kind: HttpError.default_kind(status),
      body: body
    }
  end

  @spec from_action_api_body(map()) :: t()
  def from_action_api_body(%{"error" => %{"code" => code, "info" => info}} = body) do
    %__MODULE__{
      status: 200,
      code: code,
      message: info,
      kind: action_api_kind(code),
      body: body
    }
  end

  @impl MusicLibrary.ErrorResponse
  @spec retryable?(t()) :: boolean()
  def retryable?(%__MODULE__{kind: kind}) when kind in [:rate_limit, :server_error, :timeout],
    do: true

  def retryable?(%__MODULE__{}), do: false

  @impl MusicLibrary.ErrorResponse
  @spec retry_delay_seconds(t()) :: pos_integer()
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
