defmodule SqliteVec.Ecto.Float32 do
  @moduledoc """
  `Ecto.Type` for `SqliteVec.Float32`
  """
  use Ecto.Type

  @impl true
  @spec type() :: :binary
  def type, do: :binary

  @impl true
  @spec cast(any()) :: {:ok, SqliteVec.Float32.t()}
  def cast(value) do
    {:ok, SqliteVec.Float32.new(value)}
  end

  @impl true
  @spec load(binary()) :: {:ok, SqliteVec.Float32.t()}
  def load(data) do
    {:ok, SqliteVec.Float32.from_binary(data)}
  end

  @impl true
  @spec dump(SqliteVec.Float32.t()) :: {:ok, binary()} | :error
  def dump(%SqliteVec.Float32{} = vector) do
    {:ok, SqliteVec.Float32.to_binary(vector)}
  end

  def dump(_), do: :error
end
