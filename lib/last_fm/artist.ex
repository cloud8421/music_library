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
          on_tour: boolean(),
          base_url: String.t()
        }

  embedded_schema do
    field :musicbrainz_id, :string
    field :name, :string
    field :summary, :string
    field :bio, :string
    field :image, :string
    field :play_count, :integer, default: 0
    field :on_tour, :boolean, default: false
    field :base_url, :string
  end

  def from_api_response(api_response) do
    %__MODULE__{
      musicbrainz_id: api_response["mbid"],
      name: api_response["name"],
      summary: api_response["bio"]["summary"] || "",
      bio: api_response["bio"]["content"] || "",
      image: get_image(api_response),
      play_count: get_play_count(api_response),
      on_tour: api_response["ontour"] == "1",
      base_url: api_response["url"]
    }
  end

  def changeset(artist, attrs) do
    artist
    |> cast(attrs, [
      :musicbrainz_id,
      :name,
      :summary,
      :bio,
      :image,
      :play_count,
      :on_tour,
      :base_url
    ])
  end

  def events_url(artist) do
    artist.base_url <> "/+events"
  end

  defp get_image(api_response) do
    api_response["image"]
    |> Enum.find(%{"#text" => nil}, fn i -> i["size"] == "medium" end)
    |> Map.get("#text")
  end

  defp get_play_count(api_response) do
    if play_count = get_in(api_response, ["stats", "userplaycount"]) do
      String.to_integer(play_count)
    else
      0
    end
  end
end
