defmodule LastFm.Artist do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          musicbrainz_id: String.t(),
          name: String.t(),
          summary: String.t(),
          bio: String.t(),
          image: String.t(),
          play_count: non_neg_integer(),
          base_url: String.t(),
          image_data_hash: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :musicbrainz_id, :string
    field :name, :string
    field :summary, :string
    field :bio, :string
    field :image, :string
    field :play_count, :integer, default: 0
    field :base_url, :string
    field :image_data_hash, :string
  end

  @spec from_api_response(map()) :: t()
  def from_api_response(api_response) do
    %__MODULE__{
      musicbrainz_id: api_response["mbid"],
      name: api_response["name"],
      summary: api_response["bio"]["summary"] || "",
      bio: api_response["bio"]["content"] || "",
      image: get_image(api_response),
      play_count: get_play_count(api_response),
      base_url: api_response["url"]
    }
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(artist, attrs) do
    artist
    |> cast(attrs, [
      :musicbrainz_id,
      :name,
      :summary,
      :bio,
      :image,
      :play_count,
      :base_url
    ])
    |> validate_required([:name])
  end

  defp get_image(api_response) do
    api_response["image"]
    |> Enum.find(%{"#text" => nil}, fn i -> i["size"] == "extralarge" end)
    |> Map.get("#text")
  end

  defp get_play_count(api_response) do
    case get_in(api_response, ["stats", "userplaycount"]) do
      nil -> 0
      value -> parse_play_count(value)
    end
  end

  defp parse_play_count(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> 0
    end
  end

  defp parse_play_count(_), do: 0
end
