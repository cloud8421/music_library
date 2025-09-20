defmodule MusicLibrary.Assets.Cache do
  def new do
    :ets.new(__MODULE__, [:named_table, :public, :compressed, read_concurrency: true])
  end

  def set(payload, format, content) do
    inserted_at = DateTime.utc_now() |> DateTime.to_unix()
    :ets.insert(__MODULE__, {{payload, format}, inserted_at, content})
  end

  def get(payload, format) do
    case :ets.lookup(__MODULE__, {payload, format}) do
      [{{^payload, ^format}, _inserted_at, content}] -> {:found, content}
      [] -> :not_found
    end
  end

  def total_content_size do
    :ets.foldl(
      fn {_key, _inserted_at, content}, acc -> acc + byte_size(content) end,
      0,
      __MODULE__
    )
  end

  def prune(older_than_seconds) do
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
