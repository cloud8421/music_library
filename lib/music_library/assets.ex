defmodule MusicLibrary.Assets do
  alias MusicLibrary.Assets.{Asset, Cache}
  alias MusicLibrary.Repo

  import Ecto.Query

  @doc """
  Store any file type - the responsibility to correctly populate format and
  properties is left to the caller.
  """
  @spec store(map()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  def store(params) do
    %Asset{}
    |> Asset.changeset(params)
    |> Repo.insert(on_conflict: :nothing, returning: true)
  end

  @doc """
  Store image files - properties will be computed automatically.
  """
  @spec store_image(map()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  def store_image(params) do
    %Asset{}
    |> Asset.image_changeset(params)
    |> Repo.insert(on_conflict: :nothing, returning: true)
  end

  @spec get(String.t()) :: Asset.t() | nil
  def get(hash) do
    Repo.get(Asset, hash)
  end

  @spec get!(String.t()) :: Asset.t()
  def get!(hash) do
    Repo.get!(Asset, hash)
  end

  @spec total_content_size() :: non_neg_integer() | nil
  def total_content_size do
    q =
      from p in Asset, select: sum(fragment("length(content)"))

    Repo.one(q)
  end

  @spec track_total_content_size() :: :ok
  def track_total_content_size do
    :telemetry.execute(
      [:music_library, :assets],
      %{content_size: total_content_size()},
      %{}
    )
  end

  @spec track_total_cache_size() :: :ok
  def track_total_cache_size do
    :telemetry.execute(
      [:music_library, :assets],
      %{cache_size: Cache.total_content_size()},
      %{}
    )
  end
end
