defmodule LastFm.API.ErrorResponse do
  @moduledoc """
  Structured error response for Last.fm API calls.

  Last.fm is unusual among the APIs this project consumes: it returns HTTP 200
  with a `%{"error" => N, "message" => "..."}` JSON body on failure, carrying a
  numeric application-level error code in the range 2–29. Those codes map to
  the atoms declared in `t:error_atom/0`.

  The struct-based helpers (`retryable?/1`, `retry_delay_seconds/1`) exist to
  share a uniform protocol with the per-HTTP-status `ErrorResponse` modules
  used by the other APIs — see `MusicLibrary.Worker.ErrorHandler`.
  """

  @behaviour MusicLibrary.ErrorResponse

  defstruct [:error, :message]

  @type error_atom ::
          :invalid_service
          | :invalid_method
          | :authentication_failed
          | :invalid_format
          | :invalid_parameters
          | :invalid_resource
          | :operation_failed
          | :invalid_session_key
          | :invalid_api_key
          | :service_offline
          | :invalid_method_signature
          | :transient_error
          | :suspended_api_key
          | :rate_limit_exceeded

  @type t :: %__MODULE__{
          error: error_atom(),
          message: String.t()
        }

  @spec new(integer(), String.t()) :: t()
  def new(error_code, message) do
    %__MODULE__{error: map_error(error_code), message: message}
  end

  defp map_error(2), do: :invalid_service
  defp map_error(3), do: :invalid_method
  defp map_error(4), do: :authentication_failed
  defp map_error(5), do: :invalid_format
  defp map_error(6), do: :invalid_parameters
  defp map_error(7), do: :invalid_resource
  defp map_error(8), do: :operation_failed
  defp map_error(9), do: :invalid_session_key
  defp map_error(10), do: :invalid_api_key
  defp map_error(11), do: :service_offline
  defp map_error(13), do: :invalid_method_signature
  defp map_error(16), do: :transient_error
  defp map_error(26), do: :suspended_api_key
  defp map_error(29), do: :rate_limit_exceeded

  @doc """
  Returns true if the error is retryable, false otherwise.
  """
  @spec retryable_error?(atom()) :: boolean()
  def retryable_error?(error)
      when error in [:transient_error, :service_offline, :rate_limit_exceeded, :operation_failed],
      do: true

  def retryable_error?(_error), do: false

  @doc """
  Returns the recommended retry delay in milliseconds for retryable errors.
  Returns nil for non-retryable errors.
  """
  @spec retry_delay(atom()) :: pos_integer() | nil
  # 1 minute
  def retry_delay(:rate_limit_exceeded), do: 60_000
  # 30 seconds
  def retry_delay(:service_offline), do: 30_000
  # 5 seconds
  def retry_delay(:transient_error), do: 5_000
  # 5 seconds
  def retry_delay(:operation_failed), do: 5_000
  def retry_delay(_), do: nil

  @doc """
  Struct-based retryability predicate shared with other API `ErrorResponse` modules.

  Enables `MusicLibrary.Worker.ErrorHandler.to_oban_result/1` to treat Last.fm
  uniformly alongside HTTP-status-based errors without requiring callers to
  unwrap the atom first.
  """
  @impl MusicLibrary.ErrorResponse
  @spec retryable?(t()) :: boolean()
  def retryable?(%__MODULE__{error: error}), do: retryable_error?(error)

  @doc """
  Struct-based retry delay in seconds. Falls back to 30 s when the underlying
  atom has no specific delay (see `retry_delay/1`).
  """
  @impl MusicLibrary.ErrorResponse
  @spec retry_delay_seconds(t()) :: pos_integer()
  def retry_delay_seconds(%__MODULE__{error: error}) do
    case retry_delay(error) do
      ms when is_integer(ms) -> div(ms, 1000)
      nil -> 30
    end
  end
end
