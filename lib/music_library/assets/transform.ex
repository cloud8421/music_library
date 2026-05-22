defmodule MusicLibrary.Assets.Transform do
  @moduledoc """
  Represents an image transformation (hash + target width) for asset serving.

  ## Width validation

  `decode/1` validates the `width` field: it must be `nil` (serve original size)
  or a positive integer in `1..2048`. Any other value (string, negative, zero,
  float, or very large) returns `{:error, :invalid_payload}`.

  ## Canonical cache key

  `canonical_key/1` produces a deterministic `"hash:width"` string used as the
  ETS cache key in `MusicLibraryWeb.AssetController`, collapsing variant JSON
  payloads that encode the same (hash, width) into a single cache entry.
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
  @max_width 2048

  @spec decode(payload()) :: {:ok, t()} | {:error, :invalid_payload}
  def decode(payload) do
    with {:ok, decoded} <- Base.url_decode64(payload, padding: false),
         {:ok, params} when is_map(params) <- JSON.decode(decoded) do
      width = params["width"]

      if valid_width?(width) do
        {:ok, struct!(__MODULE__, %{hash: params["hash"], width: width})}
      else
        {:error, :invalid_payload}
      end
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
    case decode(payload) do
      {:ok, transform} -> transform
      {:error, :invalid_payload} -> raise ArgumentError, "invalid transform payload"
    end
  end

  @doc """
    iex> alias MusicLibrary.Assets.Transform
    iex> Transform.canonical_key(%Transform{hash: "abc123", width: 96})
    "abc123:96"
  """
  @spec canonical_key(t()) :: String.t()
  def canonical_key(%__MODULE__{hash: hash, width: width}), do: "#{hash}:#{width}"

  defp valid_width?(nil), do: true
  defp valid_width?(width) when is_integer(width) and width > 0 and width <= @max_width, do: true
  defp valid_width?(_), do: false
end

defimpl Phoenix.Param, for: MusicLibrary.Assets.Transform do
  def to_param(transform) do
    MusicLibrary.Assets.Transform.encode!(transform)
  end
end
