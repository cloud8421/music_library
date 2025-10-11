defmodule MusicLibrary.Records.RecordEmbedding.EmbeddingType do
  @moduledoc """
  Custom Ecto type for storing embedding vectors.

  Embeddings are stored as JSON-encoded arrays of floats in the database,
  but presented as Elixir lists in the application.
  """
  use Ecto.Type

  @impl true
  def type, do: :string

  @impl true
  def cast(embedding) when is_list(embedding) do
    if Enum.all?(embedding, &is_float/1) or Enum.all?(embedding, &is_number/1) do
      # Convert all numbers to floats
      {:ok, Enum.map(embedding, &to_float/1)}
    else
      :error
    end
  end

  def cast(_), do: :error

  @impl true
  def load(json) when is_binary(json) do
    case JSON.decode(json) do
      {:ok, embedding} when is_list(embedding) ->
        {:ok, Enum.map(embedding, &to_float/1)}

      _ ->
        :error
    end
  end

  def load(_), do: :error

  @impl true
  def dump(embedding) when is_list(embedding) do
    json = JSON.encode!(embedding)
    {:ok, json}
  rescue
    _ -> :error
  end

  def dump(_), do: :error

  defp to_float(n) when is_float(n), do: n
  defp to_float(n) when is_integer(n), do: n * 1.0
end
