defmodule LastFm.Artist do
  defstruct [:musicbrainz_id, :name, :bio, :image]

  @type t :: %__MODULE__{
          musicbrainz_id: String.t(),
          name: String.t(),
          bio: String.t(),
          image: String.t()
        }

  def from_api_response(api_response) do
    %__MODULE__{
      musicbrainz_id: api_response["mbid"],
      name: api_response["name"],
      bio: api_response["bio"]["summary"],
      image: get_image(api_response)
    }
  end

  defp get_image(api_response) do
    api_response["image"]
    |> Enum.find(%{"#text" => nil}, fn i -> i["size"] == "medium" end)
    |> Map.get("#text")
  end
end
