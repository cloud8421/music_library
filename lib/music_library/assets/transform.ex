defmodule MusicLibrary.Assets.Transform do
  @moduledoc """
  Represents an image transformation (hash + target width) for asset serving.
  """

  @derive JSON.Encoder
  defstruct [:hash, :width]

  @type t :: %__MODULE__{}
  @type payload :: String.t()

  @spec new(keyword() | map()) :: t()
  def new(attrs \\ %{}), do: struct!(__MODULE__, attrs)

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
  Decodes a Base64-encoded JSON payload into a transform struct.

  Returns `{:error, :invalid_payload}` if the payload is not valid Base64 or JSON.

    iex> alias MusicLibrary.Assets.Transform
    iex> payload = "eyJoYXNoIjoiYWJjMTIzIiwid2lkdGgiOjMwMH0"
    iex> Transform.decode(payload)
    {:ok, %Transform{hash: "abc123", width: 300}}

    iex> alias MusicLibrary.Assets.Transform
    iex> Transform.decode("!!!invalid")
    {:error, :invalid_payload}
  """
  @spec decode(payload()) :: {:ok, t()} | {:error, :invalid_payload}
  def decode(payload) do
    with {:ok, decoded} <- Base.url_decode64(payload, padding: false),
         {:ok, params} when is_map(params) <- JSON.decode(decoded) do
      {:ok, struct!(__MODULE__, %{hash: params["hash"], width: params["width"]})}
    else
      _ -> {:error, :invalid_payload}
    end
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

defimpl Phoenix.Param, for: MusicLibrary.Assets.Transform do
  def to_param(transform) do
    MusicLibrary.Assets.Transform.encode!(transform)
  end
end
