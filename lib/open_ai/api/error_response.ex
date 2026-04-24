defmodule OpenAI.API.ErrorResponse do
  @moduledoc """
  Structured error response for OpenAI API calls.

  OpenAI uses HTTP status codes as the primary classifier, with one critical
  body-peek exception:

    * HTTP **429** covers both `code: "rate_limit_exceeded"` (transient — retry)
      and `code: "insufficient_quota"` (permanent — billing failure, cancel).
      `from_response/1` reads `error.code` to disambiguate.

  Error body shape (non-streaming):

      %{"error" => %{"message" => ..., "type" => ..., "code" => ..., "param" => ...}}

  Mid-stream SSE `error` / `response.failed` events are handled separately in
  `OpenAI.API.chat_stream/6` and do not flow through this module.
  """

  @behaviour MusicLibrary.ErrorResponse

  alias MusicLibrary.HttpError

  @type t :: %__MODULE__{
          status: integer() | nil,
          code: String.t() | nil,
          type: String.t() | nil,
          message: String.t() | nil,
          kind: HttpError.kind(),
          body: term()
        }

  defstruct [:status, :code, :type, :message, :kind, :body]

  @spec from_response(Req.Response.t() | map()) :: t()
  def from_response(%{status: 429, body: %{"error" => %{"code" => "insufficient_quota"} = e}} = r) do
    %__MODULE__{
      status: 429,
      code: "insufficient_quota",
      type: e["type"],
      message: e["message"],
      kind: :auth_error,
      body: r.body
    }
  end

  def from_response(%{status: status, body: %{"error" => err} = body} = _response)
      when is_map(err) do
    %__MODULE__{
      status: status,
      code: err["code"],
      type: err["type"],
      message: err["message"],
      kind: HttpError.default_kind(status),
      body: body
    }
  end

  def from_response(%{status: status, body: body} = _response) do
    %__MODULE__{
      status: status,
      code: nil,
      type: nil,
      message: nil,
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
end
