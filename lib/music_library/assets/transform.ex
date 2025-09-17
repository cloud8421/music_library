defmodule MusicLibrary.Assets.Transform do
  @derive JSON.Encoder
  defstruct [:hash, :width]

  @type t :: %__MODULE__{}
  @type payload :: String.t()

  @doc """
    iex> alias MusicLibrary.Assets.Transform
    iex> transform = %Transform{hash: "abc123", width: 300}
    iex> Transform.encode!(transform)
    "eyJoYXNoIjoiYWJjMTIzIiwid2lkdGgiOjMwMH0"
  """
  @spec encode!(t()) :: payload()
  def encode!(transform) do
    transform
    |> JSON.encode!()
    |> Base.url_encode64(padding: false)
  end

  @doc """
    iex> alias MusicLibrary.Assets.Transform
    iex> payload = "eyJoYXNoIjoiYWJjMTIzIiwid2lkdGgiOjMwMH0"
    iex> Transform.decode!(payload)
    %Transform{hash: "abc123", width: 300}
  """
  @spec decode!(payload()) :: t()
  def decode!(payload) do
    params =
      payload
      |> Base.url_decode64!(padding: false)
      |> JSON.decode!()

    struct!(__MODULE__, %{
      hash: params["hash"],
      width: params["width"]
    })
  end
end
