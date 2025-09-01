defmodule MusicLibrary.Assets do
  alias MusicLibrary.Assets.Asset
  alias MusicLibrary.Repo

  def store(params) do
    %Asset{}
    |> Asset.changeset(params)
    |> Repo.insert()
  end
end
