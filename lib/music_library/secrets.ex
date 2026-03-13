defmodule MusicLibrary.Secrets do
  @moduledoc """
  Encrypted key-value storage for API keys and credentials.
  """

  alias MusicLibrary.Repo
  alias MusicLibrary.Secrets.Secret

  @spec store(String.t(), String.t()) :: {:ok, Secret.t()} | {:error, Ecto.Changeset.t()}
  def store(name, value) do
    %Secret{}
    |> Secret.changeset(%{name: name, value: value})
    |> Repo.insert(on_conflict: :replace_all)
  end

  @spec get!(String.t()) :: Secret.t()
  def get!(name) do
    Repo.get!(Secret, name)
  end

  @spec get(String.t()) :: Secret.t() | nil
  def get(name) do
    Repo.get(Secret, name)
  end
end
