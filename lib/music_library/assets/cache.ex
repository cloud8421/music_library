defmodule MusicLibrary.Assets.Cache do
  def new do
    :ets.new(__MODULE__, [:named_table, :public, read_concurrency: true])
  end

  def set(payload, format, content) do
    :ets.insert(__MODULE__, {{payload, format}, content})
  end

  def get(payload, format) do
    case :ets.lookup(__MODULE__, {payload, format}) do
      [{{^payload, ^format}, content}] -> {:found, content}
      [] -> :not_found
    end
  end
end
