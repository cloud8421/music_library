defmodule BraveSearch.API.ErrorResponse do
  @moduledoc """
  Structured error response for Brave Search API calls.

  Brave Search returns a consistent JSON envelope on errors:

      %{"type" => "ErrorResponse",
        "error" => %{"status" => 422, "code" => "SUBSCRIPTION_TOKEN_INVALID",
                     "detail" => "...", "meta" => %{...}}}

  HTTP status codes are the primary classifier (429 for rate limit, 5xx for
  server errors). Brave uses 422 for most validation failures including
  authentication errors that other APIs would return as 401.
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
      code: extract_code(body),
      message: extract_message(body),
      kind: HttpError.default_kind(status),
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
  def retry_delay_seconds(%__MODULE__{kind: :rate_limit}), do: 60
  def retry_delay_seconds(%__MODULE__{kind: :server_error}), do: 30
  def retry_delay_seconds(%__MODULE__{kind: :timeout}), do: 10
  def retry_delay_seconds(%__MODULE__{}), do: 30

  defp extract_code(%{"error" => %{"code" => code}}) when is_binary(code), do: code
  defp extract_code(_), do: nil

  defp extract_message(%{"error" => %{"detail" => msg}}) when is_binary(msg), do: msg
  defp extract_message(_), do: nil
end
