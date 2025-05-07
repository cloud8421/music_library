defmodule MusicLibrary.Secrets do
  alias MusicLibrary.Repo
  alias MusicLibrary.Secrets.Secret

  def store(name, value) do
    %Secret{}
    |> Secret.changeset(%{name: name, value: value})
    |> Repo.insert(on_conflict: :replace_all)
  end

  def get!(name) do
    Repo.get!(Secret, name)
  end

  def get(name) do
    Repo.get(Secret, name)
  end
end
