defmodule LastFm.API.ErrorResponse do
  defstruct [:error, :message]

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
  def retryable_error?(error)
      when error in [:transient_error, :service_offline, :rate_limit_exceeded, :operation_failed],
      do: true

  def retryable_error?(_error), do: false

  @doc """
  Returns the recommended retry delay in milliseconds for retryable errors.
  Returns nil for non-retryable errors.
  """
  # 1 minute
  def retry_delay(:rate_limit_exceeded), do: 60_000
  # 30 seconds
  def retry_delay(:service_offline), do: 30_000
  # 5 seconds
  def retry_delay(:transient_error), do: 5_000
  # 5 seconds
  def retry_delay(:operation_failed), do: 5_000
  def retry_delay(_), do: nil
end
