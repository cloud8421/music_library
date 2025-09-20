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
end
