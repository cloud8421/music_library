defmodule MusicLibrary.RetryDelay do
  @moduledoc """
  Parses provider retry/reset headers into clamped snooze delays.

  Header values come from upstream APIs and should not be trusted blindly. Parsed
  values are clamped to keep Oban snoozes useful without allowing pathological
  values to churn jobs or stall them for too long.
  """

  alias Req.Response

  @min_seconds 5
  @max_seconds 300

  @doc """
  Parses a `Retry-After` header that contains seconds.
  """
  @spec retry_after_seconds(Response.t() | map()) :: pos_integer() | nil
  def retry_after_seconds(response), do: integer_header_seconds(response, "retry-after")

  @doc """
  Parses a reset header containing one or more comma-separated second values.
  """
  @spec reset_seconds(Response.t() | map(), String.t()) :: pos_integer() | nil
  def reset_seconds(response, header_name), do: integer_header_seconds(response, header_name)

  @doc """
  Parses OpenAI request/token reset duration headers.
  """
  @spec openai_reset_seconds(Response.t() | map()) :: pos_integer() | nil
  def openai_reset_seconds(response) do
    values =
      header_values(response, "retry-after") ++
        header_values(response, "x-ratelimit-reset-requests") ++
        header_values(response, "x-ratelimit-reset-tokens")

    values
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.map(&parse_openai_reset/1)
    |> max_clamped()
  end

  defp integer_header_seconds(response, header_name) do
    response
    |> header_values(header_name)
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.map(&parse_positive_integer/1)
    |> max_clamped()
  end

  defp header_values(%{headers: _} = response, header_name) do
    Response.get_header(response, String.downcase(header_name))
  end

  defp header_values(_response, _header_name), do: []

  defp parse_positive_integer(value) do
    value = String.trim(value)

    case Integer.parse(value) do
      {seconds, ""} when seconds >= 0 -> seconds
      _ -> nil
    end
  end

  defp parse_openai_reset(value) do
    case parse_positive_integer(value) do
      seconds when is_integer(seconds) -> seconds
      nil -> parse_duration(value)
    end
  end

  defp parse_duration(value) do
    value = String.trim(value)

    case Regex.scan(~r/(\d+(?:\.\d+)?)(ms|s|m)/i, value) do
      [] -> nil
      parts -> parts_to_seconds(parts, value)
    end
  end

  defp parts_to_seconds(parts, value) do
    parsed =
      Enum.map(parts, fn [_token, amount, unit] ->
        {parse_number(amount), String.downcase(unit)}
      end)

    rebuilt =
      Enum.map_join(parts, fn [token, _amount, _unit] -> String.downcase(token) end)

    normalized = value |> String.downcase() |> String.replace(~r/\s+/, "")

    if rebuilt == normalized do
      total_duration_seconds(parsed)
    else
      nil
    end
  end

  defp total_duration_seconds(parts) do
    parts
    |> Enum.map(fn {amount, unit} -> duration_to_seconds(amount, unit) end)
    |> Enum.reduce_while(0, fn
      nil, _total -> {:halt, nil}
      seconds, total -> {:cont, total + seconds}
    end)
  end

  defp parse_number(amount) do
    case Float.parse(amount) do
      {number, ""} -> number
      _ -> nil
    end
  end

  defp duration_to_seconds(nil, _unit), do: nil
  defp duration_to_seconds(amount, _unit) when amount < 0, do: nil
  defp duration_to_seconds(amount, "ms"), do: ceil(amount / 1000)
  defp duration_to_seconds(amount, "s"), do: ceil(amount)
  defp duration_to_seconds(amount, "m"), do: ceil(amount * 60)

  defp max_clamped(values) do
    values
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> nil end)
    |> clamp()
  end

  defp clamp(nil), do: nil
  defp clamp(seconds) when seconds < @min_seconds, do: @min_seconds
  defp clamp(seconds) when seconds > @max_seconds, do: @max_seconds
  defp clamp(seconds), do: seconds
end
