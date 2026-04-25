defmodule MusicBrainz.API.ErrorResponse do
  @moduledoc """
  Structured error response for MusicBrainz API calls.

  MusicBrainz uses classic HTTP status codes as the error channel. The body is a
  flat JSON `{"error": "message"}` with no numeric application codes.

  ## Rate limiting

  MusicBrainz signals rate limiting with **HTTP 503**, not 429. The service does
  not use 429 at all — a 503 response with a `Retry-After` header is the rate
  limit signal. `from_response/1` therefore maps 503 to `:rate_limit` (not the
  generic `:server_error` classification from `MusicLibrary.HttpError`).
  """

  @behaviour MusicLibrary.ErrorResponse

  alias MusicLibrary.HttpError
  alias MusicLibrary.RetryDelay

  @type t :: %__MODULE__{
          status: integer() | nil,
          message: String.t() | nil,
          kind: HttpError.kind(),
          body: term(),
          retry_delay_seconds: pos_integer() | nil
        }

  defstruct [:status, :message, :kind, :body, :retry_delay_seconds]

  @spec from_response(Req.Response.t() | map()) :: t()
  def from_response(%{status: 503, body: body} = response) do
    %__MODULE__{
      status: 503,
      message: extract_message(body),
      kind: :rate_limit,
      body: body,
      retry_delay_seconds: RetryDelay.retry_after_seconds(response)
    }
  end

  def from_response(%{status: status, body: body} = response) do
    %__MODULE__{
      status: status,
      message: extract_message(body),
      kind: HttpError.default_kind(status),
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

  def retry_delay_seconds(%__MODULE__{kind: :rate_limit}), do: 60
  def retry_delay_seconds(%__MODULE__{kind: :server_error}), do: 30
  def retry_delay_seconds(%__MODULE__{kind: :timeout}), do: 10
  def retry_delay_seconds(%__MODULE__{}), do: 30

  defp extract_message(%{"error" => message}) when is_binary(message), do: message
  defp extract_message(_), do: nil
end
