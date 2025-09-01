defmodule MusicLibrary.Assets do
  alias MusicLibrary.Assets.Asset
  alias MusicLibrary.Repo

  @doc """
  Store any file type - the responsibility to correctly populate format and
  properties is left to the caller.
  """
  def store(params) do
    %Asset{}
    |> Asset.changeset(params)
    |> Repo.insert(on_conflict: :nothing, returning: true)
  end

  @doc """
  Store image files - properties will be computed automatically.
  """
  def store_image(params) do
    %Asset{}
    |> Asset.image_changeset(params)
    |> Repo.insert(on_conflict: :nothing, returning: true)
  end

  def get(hash) do
    Repo.get(Asset, hash)
  end

  def get!(hash) do
    Repo.get!(Asset, hash)
  end
end
