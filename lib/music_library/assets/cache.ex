defmodule MusicLibrary.Assets.Cache do
  @moduledoc """
  ETS-based asset cache with TTL for serving frequently accessed images.
  """

  @spec new() :: :ets.table()
  def new do
    :ets.new(__MODULE__, [:named_table, :public, :compressed, read_concurrency: true])
  end

  @spec set(String.t(), String.t(), binary()) :: true
  def set(payload, format, content) do
    inserted_at = DateTime.utc_now() |> DateTime.to_unix()
    :ets.insert(__MODULE__, {{payload, format}, inserted_at, content})
  end

  @spec get(String.t(), String.t()) :: {:found, binary()} | :not_found
  def get(payload, format) do
    case :ets.lookup(__MODULE__, {payload, format}) do
      [{{^payload, ^format}, _inserted_at, content}] -> {:found, content}
      [] -> :not_found
    end
  end

  @spec total_content_size() :: non_neg_integer()
  def total_content_size do
    :ets.foldl(
      fn {_key, _inserted_at, content}, acc -> acc + byte_size(content) end,
      0,
      __MODULE__
    )
  end

  @one_week_seconds 60 * 60 * 24 * 7

  @spec prune(non_neg_integer()) :: non_neg_integer()
  def prune(older_than_seconds \\ @one_week_seconds) do
    threshold =
      DateTime.utc_now()
      |> DateTime.add(older_than_seconds * -1, :second)
      |> DateTime.to_unix()

    :ets.select_delete(
      __MODULE__,
      [{{:"$1", :"$2", :"$3"}, [{:<, :"$2", threshold}], [true]}]
    )
  end
end
